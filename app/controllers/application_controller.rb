# coding: utf-8
class ApplicationController < ActionController::Base
  include ControllerAuthentication
  protect_from_forgery
  def connection_pg
    PGconn.connect("203.151.201.129",5432,nil,nil,"dsi","admin")
  end
  def create_hili_map(table,gid)
    ##### Start create hilimap according to query with exact = 1
    geom = "POLYGON"
    filter = "gid = #{gid}"
    if table =~ /muban/
      geom = "POINT"
    end
  
    src = open('/ms603/map/search.tpl').readlines
    dst = open('/ms603/map/hili.map','w')
    
    src.each do |line|
      if line =~ /XXGEOMXX/
        line = line.gsub(/XXGEOMXX/,"#{geom}")
      elsif line =~ /XXTABLE/
        line = line.gsub(/XXTABLEXX/,"#{table}")
      elsif line =~ /XXFILTERXX/
        line = line.gsub(/XXFILTERXX/,"#{filter}")
      end
      dst.write(line)
    end
    dst.close
    ##### End of create hilight
  
  end

  def get_center(table,gid)
    con = connection_pg
    sql = "SELECT center(the_geom) as centerx "
    sql += "FROM #{table} "
    sql += "WHERE gid=#{gid}"
    
    
    res = con.exec(sql)
    con.close
    found = res.num_tuples
    lonlat = []
    if (found == 1)
      res.each do |rec|
        lonlat = rec['centerx'].to_s.tr('()','').split(',')
        lon = sprintf("%0.2f", lonlat[0].to_f)
        lat = sprintf("%0.2f", lonlat[1].to_f)
        lonlat = [lon,lat]
      end
    end
    lonlat
  end
  
  def search_location(query, start, limit, exact)
    lon = lat = 0.0
    con = connection_pg
    cond = nil
    if exact == 1
      sql = "SELECT loc_gid,loc_text,loc_table "
      sql += "FROM locations "
      sql += "WHERE loc_text = '#{query}' LIMIT 1"
      res = con.exec(sql)
  
      gid = 0
      text = nil
      table = nil
      res.each do |rec|
        gid = rec['loc_gid']
        text = rec['loc_text']
        table = rec['loc_table']
      end
    
      lonlat = get_center(table,gid)
      lon = lonlat[0]
      lat = lonlat[1]  
    
      create_hili_map(table,gid)
    
      return_data = Hash.new
      return_data[:success] = true
      return_data[:totalcount] = 1
      return_data[:records] = [{
        :loc_gid => gid,
        :loc_text => text,
        :loc_table => table,
        :lon => lon, 
        :lat => lat
      }]    
      return return_data
    end
    
    if query =~ /\./
      cond = "loc_text LIKE '#{query}%' "
    elsif query.to_s.strip =~ /\ /
      kws = query.strip.split(' ')
      (0..kws.length-1).each do |n|
        if n == 0
          if kws[0][1..1] == '.' # ต. อ. จ.
            cond = "loc_text LIKE '#{kws[n]}%' "
          else
            cond = "loc_text LIKE '%#{kws[n]}%' "
          end
        else
          cond += "AND loc_text LIKE '%#{kws[n]}%' "
        end
      end
    else
      cond = "loc_text LIKE '%#{query}%' "
    end
  
    
    sql = "SELECT count(*) as cnt FROM locations WHERE #{cond}" 
  
    res = con.exec(sql)
    found = 0
    res.each do |rec|
      found = rec['cnt'].to_i
    end
  
    return_data = nil
    
    if (found > 1)
      sql = "SELECT loc_gid,loc_text,loc_table "
      sql += "FROM locations "
      sql += "WHERE #{cond} "
      sql += "ORDER BY id DESC "
      sql += "LIMIT #{limit} OFFSET #{start}"
  
      res = con.exec(sql)
      records = []
      res.each do |rec|
        gid = rec['loc_gid']
        text = rec['loc_text']
        table = rec['loc_table']
        h = {:loc_gid => "#{gid}", :loc_text => "#{text}", :loc_table => "#{table}"}
        records.push(h)
      end
      
      
      return_data = Hash.new
      return_data[:success] = true
      return_data[:totalcount] = found
      return_data[:records] = records
      
    elsif found == 1
      sql = "SELECT loc_gid,loc_text,loc_table "
      sql += "FROM locations "
      sql += "WHERE loc_text LIKE '%#{query}%' "
  
      res = con.exec(sql)
      gid = 0
      text = nil
      table = nil
      res.each do |rec|
        gid = rec['loc_gid']
        text = rec['loc_text']
        table = rec['loc_table']
      end
    
      lonlat = get_center(table,gid)
      lon = lonlat[0]
      lat = lonlat[1]  
    
      create_hili_map(table,gid)
    
      return_data = Hash.new
      return_data[:success] = true
      return_data[:totalcount] = 1
      return_data[:records] = [{
        :loc_gid => gid,
        :loc_text => text,
        :loc_table => table,
        :lon => lon, 
        :lat => lat
      }]
    else # found == 0
      return_data = Hash.new
      return_data[:success] = true
      return_data[:totalcount] = 0
      return_data[:records] = [{}]
    end
    con.close
    return_data
  end
  
  def insert_location(text, tbl, gid)
    con = connection_pg
    sql = "INSERT INTO locations (loc_text,loc_table,loc_gid) "
    sql += "VALUES ('#{text}','#{tbl}','#{gid}')"
    con.exec(sql)
    con.close
  end
  
  def check_npark(lon,lat)
    con = connection_pg
    sql = "select name_th from national_park where contains(the_geom,"
    sql += "geometryfromtext('POINT(#{lon} #{lat})',4326))"
    res = con.exec(sql)
    con.close
    found = res.num_tuples
    name = "NA"
    if (found == 1)
      res.each do |rec|
        name = '<b><bi>เขตอุทยาน' << rec['name_th'] << '</i></b>'
      end
    end
    name
  end
  
  def check_rforest(lon,lat)
    con = connection_pg
    sql = "select name_th,mapsheet,area_decla,dec_date,ratchakija,ton "
    sql += "from reserve_forest "
    sql += "where contains(the_geom,"
    sql += "geometryfromtext('POINT(#{lon} #{lat})',4326))"
    res = con.exec(sql)
    con.close
    found = res.num_tuples
    msg = "NA"
    if (found == 1)
      res.each do |rec|
        name = rec['name_th']
        mapsheet = rec['mapsheet']
        area_decla = rec['area_decla']
        # Add comma to large number
        area_decla = area_decla.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
        dec_date = rec['dec_date']
        ratchakija = rec['ratchakija']
        ton = rec['ton']
        msg = "<font face=\"time, serif\" size=\"4\"><b><i>เขตป่าสงวน#{name}</i></b><br />ระวาง: #{mapsheet}<br/>"
        msg += "เนื้อที่: #{area_decla} ไร่<br />"
        msg += "ประกาศเมื่อ: #{dec_date}<br />"
        msg += "ราชกิจจานุเบกษา เล่ม: #{ratchakija} ตอนที่: #{ton}</font>"
      end
    end
    msg 
  end
  
  def check_m30forest(lon,lat)
    con = connection_pg
    sql = "select area,rai "
    sql += "from mangrove_2530 "
    sql += "where contains(the_geom,"
    sql += "geometryfromtext('POINT(#{lon} #{lat})',4326))"
    res = con.exec(sql)
    con.close
    found = res.num_tuples
    msg = "NA"
    if (found == 1)
      res.each do |rec|
        area = sprintf("%.2f", rec['area'].to_f)
        rai = sprintf("%.2f", rec['rai'].to_f)
        msg = "<font face=\"time, serif\" size=\"4\"><b><i>เขตป่าชายเลน 2530</i></b><br />"
        msg += "พื้นที่:#{area} ตร.ม. (#{rai} ไร่)</font>"
      end
    end
    msg 
  end
  
  def check_m43forest(lon,lat)
    con = connection_pg
    sql = "select area,rai "
    sql += "from mangrove_2543 "
    sql += "where contains(the_geom,"
    sql += "geometryfromtext('POINT(#{lon} #{lat})',4326))"
    res = con.exec(sql)
    con.close
    found = res.num_tuples
    msg = "NA"
    if (found == 1)
      res.each do |rec|
        area = sprintf("%.2f", rec['area'].to_f)
        rai = sprintf("%.2f", rec['rai'].to_f)
        msg = "<font face=\"time, serif\" size=\"4\"><b><i>เขตป่าชายเลน 2543</i></b><br />"
        msg += "พื้นที่:#{area} ตร.ม. (#{rai} ไร่)</font>"
      end
    end
    msg 
  end
  
  def check_m52forest(lon,lat)
    con = connection_pg
    sql = "select lu52_nam,amphoe_t,prov_nam_t,sq_km "
    sql += "from mangrove_2552 "
    sql += "where contains(the_geom,"
    sql += "geometryfromtext('POINT(#{lon} #{lat})',4326))"
    res = con.exec(sql)
    con.close
    found = res.num_tuples
    msg = "NA"
    if (found == 1)
      res.each do |rec|
        name = rec['lu52_nam']
        amp = rec['amphoe_t']
        prov = rec['prov_nam_t']
        area = sprintf("%.2f", rec['sq_km'].to_f)
        msg = "<font face=\"time, serif\" size=\"4\"><b><i>เขต#{name} 2552</i></b><br />"
        msg += "#{amp} #{prov}<br />"
        msg += "พื้นที่:#{area} ตร.ม.</font>"
      end
    end
    msg 
  end
  
  def dms2dd(dd,mm,ss)
    d = dd.to_f
    m = mm.to_f / 60.0
    s = ss.to_f / 3600.0
    decimal_degree = d + m + s
  end

  def check_npark2(lon,lat)
    con = connection_pg
    sql = "select name_th from national_park where contains(the_geom,"
    sql += "geometryfromtext('POINT(#{lon} #{lat})',4326))"
    res = con.exec(sql)
    con.close
    found = res.num_tuples
    name = "NA"
    if (found == 1)
      res.each do |rec|
        name = rec['name_th']
      end
    end
    name
  end
  
  def check_rforest2(lon,lat)
    con = connection_pg
    sql = "select name_th from reserve_forest where contains(the_geom,"
    sql += "geometryfromtext('POINT(#{lon} #{lat})',4326))"
    res = con.exec(sql)
    con.close
    found = res.num_tuples
    name = "NA"
    if (found == 1)
      res.each do |rec|
        name = rec['name_th']
      end
    end
    name
  end

  def convert_gcs(n,e,z)
    if z == '47'
      srid = 32647
    else
      srid = 32648
    end
  
    con = connection_pg
    sql = "SELECT astext(transform(geometryfromtext('POINT(#{e} #{n})',#{srid}), 4326)) as geom"
    res = con.exec(sql)
    con.close
  
    #POINT(100.566084211455 13.8907665943153)
    point = res[0]['geom'].to_s.split('(').last.tr(')','').split(' ')
    lon = point.first
    lat = point.last
    return [lon,lat]
  end
  
  def check_uforest(lon,lat)
    con = connection_pg
    sql = "select forest_n from use_forest where contains(the_geom,"
    sql += "geometryfromtext('POINT(#{lon} #{lat})',4326))"
    res = con.exec(sql)
    con.close
    found = res.num_tuples
    name = "NA"
    if (found == 1)
      name = res[0]['forest_n']
    end
    name
  end

  def generate_kml(layername)
    con = connection_pg
    sql = "select id,kmlname,name,descr,imgname,astext(the_geom) as geom "
    sql += "FROM kml "
    sql += "WHERE kmlname = '#{layername}' "
    res = con.exec(sql)
    con.close
    
    header = open("#{Rails.root}/public/rb/#{layername}-header").readlines.join()
    footer = open("#{Rails.root}/public/rb/#{layername}-footer").readlines.join()
  
    place = nil
    
    n = 0
    res.each do |rec|
      n += 1
      id = rec['id']
      kmlname = rec['kmlname']
      name = rec['name']
      descr = rec['descr']
      imgname = rec['imgname']
      geom = rec['geom']
      coord = 'NA'
      if geom =~ /POINT/
        ll = geom.split('POINT(').last.split(')').first
        coord = ll.tr(' ',',')
      end
  
      if (n == 1)
        place =  "        <Placemark>\n"
      else
        place +=  "        <Placemark>\n"
      end
      place += "          <id>#{id}</id>\n"
      place += "          <name>#{name}</name>\n"
      place += "          <styleUrl>#marker</styleUrl>\n"
      place += "          <description>#{descr}</description>\n"
  
      if (imgname.to_s.length > 0)
        place += "          <imgUrl>http://203.151.201.129/dsix/photos/#{imgname}</imgUrl>\n"
      end
      
      if (geom =~ /POINT/)
        place += "          <Point>\n"
        place += "            <coordinates>#{coord}</coordinates>\n"
        place += "          </Point>\n"
        place += "        </Placemark>\n"
      end    
    end
    kml = header << place << footer
    
    # Write new kml to file
    File.open("../kml/#{layername}.kml","w").write(kml)
  end

  def check_records()
    con = PGconn.connect("localhost",5432,nil,nil,"dsi","admin")
    sql = "SELECT * FROM kml "
    res = con.exec(sql)
    found = res.num_tuples
    if (found == 0)
      sql = "ALTER SEQUENCE kml_id_seq RESTART WITH 1"
      res = con.exec(sql)
    end
    con.close
  end
  
  
  def insert_kml(kmlname,name,descr,imgname,loc)
    con = PGconn.connect("localhost",5432,nil,nil,"dsi","admin")
    sql = "INSERT INTO kml (kmlname,name,descr,imgname,the_geom) "
    sql += "VALUES('#{kmlname}','#{name}','#{descr}','#{imgname}',geometryfromtext(\'#{loc}\',4326))"
    con.exec(sql)
    con.close
  end
  
  def google(kw)
  
    w = Net::HTTP.new("maps.google.co.th")
    req = "/maps?q=#{kw}"
  
    resp,data = w.get(req)
  
    data = data.gsub(/\}/,"\n")
  
    lon = lat = nil
  
    data.each do |line|
      l = line.chomp.gsub(/<.*?>/,'').strip
      if l =~ /viewport\:\{center\:/
        ll = l.split(/lat/).last.tr(':','').split(/\,lng/)
        lon = ll.last
        lat = ll.first
        break
      end
    end
    lonlat = [lon,lat]
  end

  def get_center2(text, table)
    text = text.split(' ').first
    if table =~ /province/
      cond = "prov_nam_t LIKE '%#{text}%'"
    elsif table =~ /amphoe/
      cond = "amphoe_t LIKE '%#{text}%'"
    elsif table =~ /tambon/
      cond = "tam_nam_t LIKE '%#{text}%'"
    elsif table =~ /muban/
      cond = "muban LIKE '%#{text}%'"
    else
      cond = "1 = 1"
    end
    con = PGconn.connect("localhost",5432,nil,nil,"dsi")
    sql = "SELECT center(the_geom) "
    sql += "FROM #{table} "
    sql += "WHERE #{cond}"
    res = con.exec(sql)
    con.close
    found = res.num_tuples
    lonlat = []
    if (found > 0)
      res.each do |rec|
        lonlat = rec[0].to_s.tr('()','').split(',')
      end
    end
    lonlat
  end

  def search_location2(kw)
  
    con = PGconn.connect("localhost",5432,nil,nil,"dsi")
    sql = "SELECT loc_text,loc_table "
    sql += "FROM locations "
    sql += "WHERE loc_text LIKE '%#{kw}%' "
    sql += "ORDER BY id DESC"
    res = con.exec(sql)
    con.close
    data = []
    text = table = nil
    found = res.num_tuples
    match = false
  
    if (found > 0)
      res.each do |rec|
        xtext = rec[0]
        xtable = rec[1]
        if (xtable =~ /muban/ && !match)
          text = xtext
          table = xtable
          match = true if (text =~ /#{kw}/)
        end
        if (xtable =~ /province/)
          text = xtext
          table = xtable
          match = true if (text =~ /#{kw}/)
        end
        if (xtable =~ /amphoe/)
          text = xtext
          table = xtable
          match = true if (text =~ /#{kw}/)
        end
        if (xtable =~ /tambon/)
          text = xtext
          table = xtable
          match = true if (text =~ /#{kw}/)
        end    
      end
    end
    lonlat = get_center2(text, table)
    data = [text,table] << lonlat
    data    
  end
  
  def check_ccaatt(kw)
    con = PGconn.connect("localhost",5432,nil,nil,"dsi","postgres")
    sql = "select gid,prov_nam_t,center from province where prov_nam_t LIKE '%#{kw}%' "
    sql += "ORDER BY gid"
    res = con.exec(sql)
    con.close
    found = res.num_tuples
    name = center = nil
    lon = lat = nil
    i = []
    if (found == 1)
      gid = res[0][0]
      name = res[0][1]
      center = res[0][2]
      ll = center.split(',')
      lon = ll.first
      lat = ll.last
    else
      gid = res[0][0]
      name = res[0][1]
      center = res[0][2]
      ll = center.split(',')
      lon = ll.first
      lat = ll.last
    end
    i.push(gid)
    i.push(name)
    i.push(lon)
    i.push(lat)
    i
  end
  
  def update_province(gid, center)
    con = PGconn.connect("localhost",5432,nil,nil,"dsi","postgres")
    sql = "UPDATE province SET center='#{center}' "
    sql += "WHERE gid='#{gid}' "
    con.exec(sql)
    con.close
  end

end
