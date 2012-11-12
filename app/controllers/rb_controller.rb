# -*- encoding : utf-8 -*-
class RbController < ApplicationController
  before_filter :login_required
  def search_googlex
    query = params[:query]
    start = params[:start].to_i
    limit = params[:limit].to_i
    exact = params[:exact].to_s.to_i
    if start == 0
      limit = 5
    end
    data = search_location(query, start, limit, exact)
    render :text => data.to_json
  end
  
  def add_text_to_locations
    # no_02_province
    tbl = "no_02_province"
    con = connection_pg
    sql = "SELECT prov_nam_t,gid FROM no_02_province"
    res = con.exec(sql)
    con.close
    
    res.each do |rec|
      text = rec[0].to_s.strip
      gid = rec[1]
      insert_location(text,tbl,gid)
    end
    
    # no_03_amphoe
    tbl = "no_03_amphoe"
    con = connection_pg
    sql = "SELECT amphoe_t,gid FROM no_03_amphoe"
    res = con.exec(sql)
    con.close
    
    res.each do |rec|
      text = rec[0].to_s.strip
      gid = rec[1]
      insert_location(text,tbl,gid)
    end
    
    # no_04_tambon
    tbl = "no_04_tambon"
    con = connection_pg
    sql = "SELECT tam_nam_t,gid FROM no_04_tambon"
    res = con.exec(sql)
    con.close
    
    res.each do |rec|
      text = rec[0].to_s.strip
      gid = rec[1]
      insert_location(text,tbl,gid)
    end
    
    # no_06_muban
    tbl = "no_06_muban"
    con = connection_pg
    sql = "SELECT muban,gid FROM no_06_muban"
    res = con.exec(sql)
    con.close
    
    n = 1
    res.each do |rec|
      text = rec[0].to_s.strip
      gid = rec[1]
      insert_location(text,tbl,gid)
      n += 1
      sleep(3) if n % 5000 == 0
    end
    render :text => " "
  end
  
  def check_forest_info
    layer = params[:layer]
    lon = params[:lon].to_f
    lat = params[:lat].to_f
    
    msg = nil
    
    if layer == 'national_park'
      msg = check_npark(lon,lat)
    elsif layer == 'reserve_forest'
      msg = check_rforest(lon,lat)
    elsif layer == 'mangrove_2530'
      msg = check_m30forest(lon,lat)
    elsif layer == 'mangrove_2543'
      msg = check_m43forest(lon,lat)
    elsif layer == 'mangrove_2552'
      msg = check_m52forest(lon,lat)
    end
    
    data = "{'msg':'#{msg}','lon':'#{lon}','lat':'#{lat}'}"
    
    render :text => data
  end
  def checkLonLat
    lodd = params[:lodd]
    lomm = params[:lomm]
    loss = params[:loss]
    ladd = params[:ladd]
    lamm = params[:lamm]
    lass = params[:lass]
    lon = dms2dd(lodd,lomm,loss)
    lat = dms2dd(ladd,lamm,lass)
    con = connection_pg
    sql = "select name_th from national_park where contains(the_geom, geometryfromtext('POINT(#{lon} #{lat})',4326))"
    res = con.exec(sql)
    con.close
    found = res.num_tuples
    if (found > 0)
      name = res[0][0]
      msg = "พิกัด #{ladd}&deg; #{lamm}&apos; #{lass}&quot; N "
      msg += "#{lodd}&deg; #{lomm}&apos; #{loss}&quot; E<br><br>"
      msg += "<b><font color=\"red\">อยู่ในเขตอุทยานแห่งชาติ#{name}</font></b>"
    else
      msg = "พิกัด #{ladd}&deg; #{lamm}&apos; #{lass}&quot; N "
      msg += "#{lodd}&deg; #{lomm}&apos; #{loss}&quot; E<br><br>"
      msg += "<b><font color=\"green\">ไม่อยู่ในเขตอุทยานแห่งชาติ</font></b>"
    end
    data = "{'msg':'#{msg}','lon':'#{lon}','lat':'#{lat}'}"
    render :text => data  
  end
  
  def checkLonLat2
    lodd = params[:lodd]
    lomm = params[:lomm]
    loss = params[:loss]
    ladd = params[:ladd]
    lamm = params[:lamm]
    lass = params[:lass]
    
    lon = dms2dd(lodd,lomm,loss)
    lat = dms2dd(ladd,lamm,lass)
    
    npark = check_npark2(lon,lat)
    rforest = check_rforest2(lon,lat)
    
    msg = "พิกัด #{ladd}&deg; #{lamm}&apos; #{lass}&quot; N "
    msg += "#{lodd}&deg; #{lomm}&apos; #{loss}&quot; E<br>"
    
    if (npark == "NA")
      msg += "<br><b><font color=\"green\">ไม่อยู่ในเขตอุทยานแห่งชาติ</font></b>"
    else
      msg += "<br><b><font color=\"red\">อยู่ในเขตอุทยานแห่งชาติ#{npark}</font></b>"
    end
    
    if (rforest == "NA")
      msg += "<br><b><font color=\"green\">ไม่อยู่ในเขตป่าสงวน</font></b>"
    else
      msg += "<br><b><font color=\"red\">อยู่ในเขตป่าสงวน#{rforest}</font></b>"
    end
    
    data = "{'msg':'#{msg}','lon':'#{lon}','lat':'#{lat}'}"
    
    render :text => data    
  end
  
  def checkLonLatDD
    lon = params[:lon]
    lat = params[:lat]
    npark = check_npark2(lon,lat)
    rforest = check_rforest2(lon,lat)
    msg = ""
    if (npark == "NA")
      msg += "<br><b><font color=\"green\">ไม่อยู่ในเขตอุทยานแห่งชาติ</font></b>"
    else
      msg += "<br><b><font color=\"red\">อยู่ในเขตอุทยานแห่งชาติ#{npark}</font></b>"
    end
    
    if (rforest == "NA")
      msg += "<br><b><font color=\"green\">ไม่อยู่ในเขตป่าสงวน</font></b>"
    else
      msg += "<br><b><font color=\"red\">อยู่ในเขตป่าสงวน#{rforest}</font></b>"
    end
    data = "{'msg':'#{msg}','lon':'#{lon}','lat':'#{lat}'}"
    render :text => data    
  end
  
  def checkUTM
    utmn = params[:utmn]
    utme = params[:utme]
    zone = params[:zone]
    
    lonlat = convert_gcs(utmn, utme, zone)
    
    lon = lonlat.first
    lat = lonlat.last
    
    npark = check_npark2(lon,lat)
    rforest = check_rforest2(lon,lat)
    
    msg = "พิกัด #{utmn}:N "
    msg += "#{utme}:E<br>"
    msg += "Zone #{zone} (WGS84)<br>"
    
    if (npark == "NA")
      msg += "<br><b><font color=\"green\">ไม่อยู่ในเขตอุทยานแห่งชาติ</font></b>"
    else
      msg += "<br><b><font color=\"red\">อยู่ในเขตอุทยานแห่งชาติ#{npark}</font></b>"
    end
    
    if (rforest == "NA")
      msg += "<br><b><font color=\"green\">ไม่อยู่ในเขตป่าสงวน</font></b>"
    else
      msg += "<br><b><font color=\"red\">อยู่ในเขตป่าสงวน#{rforest}</font></b>"
    end
    
    data = "{'msg':'#{msg}','lon':'#{lon}','lat':'#{lat}'}"
    
    render :text => data    
  end
  
  def checkUTMIndian
    utmn = params[:utmn]
    utme = params[:utme]
    zone = params[:zone]
    
    lonlat = convert_gcs(utmn, utme, zone)
    
    lon = lonlat.first
    lat = lonlat.last
    
    npark = check_npark2(lon,lat)
    rforest = check_rforest2(lon,lat)
    
    msg = "พิกัด #{utmn}:N "
    msg += "#{utme}:E<br>"
    msg += "Zone #{zone} (Indian 1975)<br>"
    
    if (npark == "NA")
      msg += "<br><b><font color=\"green\">ไม่อยู่ในเขตอุทยานแห่งชาติ</font></b>"
    else
      msg += "<br><b><font color=\"red\">อยู่ในเขตอุทยานแห่งชาติ#{npark}</font></b>"
    end
    
    if (rforest == "NA")
      msg += "<br><b><font color=\"green\">ไม่อยู่ในเขตป่าสงวน</font></b>"
    else
      msg += "<br><b><font color=\"red\">อยู่ในเขตป่าสงวน#{rforest}</font></b>"
    end
    data = "{'msg':'#{msg}','lon':'#{lon}','lat':'#{lat}'}"
    
    render :text => data    
  end
  
  def createHili
    gid = params[:gid]
    map = open("/ms521/map/hili.tpl").readlines.to_s.gsub('XX',gid)
    File.open("/ms521/map/hili.map","w").write(map)    
  end
  
  def delete_feature
    id = params[:id]
    layer = params[:layer]
    con = connection_pg
    sql = "DELETE FROM kml "
    sql += "WHERE id='#{id}' "
    con.exec(sql)
    con.close
    # Rebuild KML for this layer (1/2)
    generate_kml(layer)    
  end

  def getPolygonWKT
    table = params[:table]
    gid = params[:gid]
    con = PGconn.connect("localhost",5432,nil,nil,"dsi","postgres")
    sql = "SELECT gid,astext(the_geom) "
    sql += "FROM #{table} "
    sql += "WHERE gid=#{gid} "
    res = con.exec(sql)
    con.close
    gidx = res[0][0]
    geometry = res[0][1]
    #geometry = "MULTIPOLYGON((104.97 16.27,105 16,104.5 16,104.97 16.27))"
    render :text => geometry    
  end
  
  def kml_delete
    id = params[:id]
    con = PGconn.connect("localhost",5432,nil,nil,"dsi","admin")
    sql = "DELETE FROM kml "
    sql += "WHERE id=#{id} "
    con.exec(sql)
    con.close
    data = {}
    data['success'] = true
    # Restart SEQUENCE to 1 if 0 record found in kml
    check_records()      
    render :text => data.to_json
  end
  
  def process_input
    name = params[:name]
    layer = params[:icon].split('_').last
    
    # strip icon1 -> 1 -> layer_1
    layer = layer.gsub(/icon/,'')
    
    kmlname = "layer_#{layer}"
    descr = params[:description]
    imgname = params[:imgname]
    loc = params[:location]
    
    insert_kml(kmlname,name,descr,imgname,loc)
    
    data = {}
    data['success'] = true
    
    render :text => data.to_json   
  end
  def reset_kml
    con = PGconn.connect("localhost",5432,nil,nil,"dsi","admin")
    sql = "DELETE FROM kml "
    res = con.exec(sql)
    sql = "ALTER SEQUENCE kml_id_seq RESTART WITH 1"
    res = con.exec(sql)
    con.close    
  end
  
  def search_google_new
    kw = params[:kw]
    lonlat = google(kw)
    name = kw
    lon = lonlat.first
    lat = lonlat.last
    data = "{'text':'#{text}','name':'#{name}','lon':'#{lon}','lat':'#{lat}','table':'#{table}'}"  
    render :text => data  
  end
  
  def search_google
    kw = c['kw']
    ##### Create hilight for this gid province
    mysearch = search_location2(kw)
    geom = "POLYGON"
    text = mysearch[0]
    table = mysearch[1]
    lonlat = mysearch[2]
    filter = ''
    if table =~ /province/
      filter = "prov_nam_t LIKE '%#{text}%'"
    elsif table =~ /amphoe/
      filter = "amphoe_t LIKE '%#{text}%'"
    elsif table =~ /tambon/
      filter = "tam_nam_t LIKE '%#{text}%'"
    elsif table =~ /muban/
      filter = "muban LIKE '%#{text}%'"
      geom = "POINT"
    end
    map = open("/ms521/map/search.tpl").readlines.to_s.gsub('#GEOM#',"#{geom}").gsub('#TABLE#',"#{table}").gsub('#FILTER#',"#{filter}")
    File.open("/ms521/map/hili.map","w").write(map)
    ##### End of create hilight
    if lonlat.nil?
      lonlat = google(kw)
    end
    name = kw
    lon = lonlat.first
    lat = lonlat.last
    data = "{'text':'#{text}','name':'#{name}','lon':'#{lon}','lat':'#{lat}','table':'#{table}'}"
    render :text => data   
  end
  
  def search
    kw = c['kw']
    ccaatt = check_ccaatt(kw)
    gid = ccaatt[0]
    name = ccaatt[1]
    lon = ccaatt[2]
    lat = ccaatt[3]
    msg = "1 record found"
    data = "{'msg':'#{msg}','gid':'#{gid}','name':'#{name}','lon':'#{lon}','lat':'#{lat}'}"
    # Create hilight for this gid province
    map = open("/ms521/map/hili.tpl").readlines.to_s.gsub('XX',"gid = '#{gid}'")
    File.open("/ms521/map/hili.map","w").write(map)
    render :text => data    
  end
  
  def update_center
    con = PGconn.connect("localhost",5432,nil,nil,"dsi","postgres")
    sql = "SELECT gid,center(the_geom) "
    sql += "FROM province"
    res = con.exec(sql)
    con.close
    res.each do |rec|
      gid = rec[0]
      center = rec[1].tr('()','')
      update_province(gid,center)
    end    
  end
end
