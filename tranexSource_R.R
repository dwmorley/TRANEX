## SEE THE README
## This file called as Source from tranex_R.R

## Create noise model function
run_crtn <- function(conn_st, rec, rec_id, rds, lndc, flw, ref, hgt, nds) {
  stt <- Sys.time()
  
  ##Use temp directory for intermediate files
  d <- tempdir() 
  setwd(d) 
  
  ##Set-up GRASS
  if (reflect) { 
    WPATH <- Sys.getenv("PATH") 
    WPATH1 <- paste("C:\\OSGeo4W\\bin", WPATH, sep=";") 
    Sys.setenv(PATH=WPATH1)
    
    ## Ensure this is the correct path for your system, especially GRASS version may be different
    initGRASS("C:/OSGeo4W/apps/grass/grass-7.0.4", d, override = TRUE) 
  }
  
  ##Connect to Postgresql
  drv <- dbDriver("PostgreSQL")
  con <- dbConnect(drv, host=conn_st[1], port=conn_st[2], dbname=conn_st[3], user=conn_st[4], password=conn_st[5])
  dsn_st <- paste("PG:host=", conn_st[1], "dbname=", conn_st[3], "user=", conn_st[4], "password=" ,conn_st[5], sep=" ")
  
  ##Get number of points to process
  q <- paste("select count(*) from ", receptors, sep = "")
  n <- as.integer(fetch(dbSendQuery(con, q, n = -1)))
  dbClearResult(dbListResults(con)[[1]])
  
  ##make output tables
  rs <- dbSendQuery(con, "select make_tables()")
  dbClearResult(dbListResults(con)[[1]]) 

  for (i in 1:n) {
    ##timer
    now <- Sys.time()
    
    ##get this point
    q <- paste("select get_house(", i, ",'", receptors, "','", rec_id, "')", sep = "")
    rs <- dbSendQuery(con, q)
    dbClearResult(dbListResults(con)[[1]])    
    
    ##Calculate reflections
    if (reflect) {
      ##get viewpoint      
      x <- fetch(dbSendQuery(con, "select st_x(p.geom) from this_point as p"), n = -1)
      y <- fetch(dbSendQuery(con, "select st_y(p.geom) from this_point as p"), n = -1)
      
      obs <- c(as.numeric(x), as.numeric(y))
      
      ##get heights
      q <- paste("select get_rastersubset('", heights, "','", nodes, "')", sep = "")
      rs <- dbSendQuery(con, q)
      dbClearResult(dbListResults(con)[[1]]) 
      
      ##if check if any nodes present
      q <- paste("select count(*) from node_set")
      nc <- as.integer(fetch(dbSendQuery(con, q, n = -1)))
      dbClearResult(dbListResults(con)[[1]])
      
      if (nc > 0) {        
        ##get viewshed
        try(execGRASS("v.in.ogr", flags=c("o", "overwrite", "quiet"), 
                      parameters=list( input = dsn_st, layer = "build_hc", type = "boundary", output="vDEM")), TRUE) 
        try(execGRASS("g.region", parameters=list(vector="vDEM")) , TRUE) 
        try(execGRASS("v.to.rast",  flags=c("overwrite", "quiet"), 
                      parameters=list(type = "area", input="vDEM", output = "DEM", use="attr", attribute_column="val")), TRUE)  
        try(execGRASS("r.viewshed", flags = c("b", "overwrite", "quiet"), 
                      parameters = list(input = "DEM", output = "vs_raster", coordinates =  obs, observer_elevation = 4)), TRUE)                
        try(execGRASS("r.to.vect", 
                      parameters = list(input = "vs_raster", output = "vvs", type = "area"), 
                      flags = c("overwrite", "quiet")), TRUE) 
        try(execGRASS("v.out.ogr", flags=c("overwrite", "quiet"), parameters=list( 
          input = "vvs", type = "area", output="shed.shp")), TRUE)       
        try(execGRASS("v.in.ogr", flags=c("o", "c", "overwrite", "quiet"), 
                      parameters=list(input=dsn_st, layer = "node_set", type = "boundary", output="vnode")), TRUE)       
        try(execGRASS("v.out.ogr", flags=c("overwrite", "quiet"), parameters=list( 
          input = "vnode", type = "point", output="vnodes.shp")), TRUE)
        
        rm(shed)
        rm(bldnode)
        try(shed <- readShapePoly("shed.shp"), TRUE)
        
        ##get nodes
        bldnode <- try(bldnode <- readShapePoints("vnodes.shp"), TRUE)   
        if (exists("bldnode") & exists("shed")) {
          ##Get building nodes in viewshed    
          plot(shed, col="gray", border="blue") 
          plot(bldnode, pch = 21, add = TRUE)
          bnode_in_shed <- which(over(bldnode, shed)$value == 1)
          spdf <- bldnode[bnode_in_shed,]
          plot(spdf, pch = 19, col = "red", add = TRUE)
          df <- data.frame(node_id = spdf$node_id)
        }
        else {  
          ##No nodes in viewshed
          df <- data.frame(node_id = numeric())
          frame()
          if (!exists("shed")) {
            mtext("Receptor OUTSIDE buildings raster")     
          }
          else {
            mtext("No viewshed for this point")
          }
        }
      }
      else {
        df <- data.frame(node_id = numeric())
        frame()
        mtext("No viewshed for this point")      
      }     
      rm(shed)
      rm(bldnode)
    }
    else {
      df <- data.frame(node_id = numeric())
      frame()
      mtext("No viewshed for this point")  
    }
    
    dbSendQuery(con, "drop table if exists vs_nodes")
    dbWriteTable(con, "vs_nodes", df)
    
    ##run the noise model
    q <- paste("select do_crtn('", rds, "','", lndc, "','", flw, "')", sep = "")
    laeq16 <- as.numeric(fetch(dbSendQuery(con, q, n = -1)))
    dbClearResult(dbListResults(con)[[1]])
    
    ##Time taken and result for this point
    print (paste("%%%%%% This point took: ", round(Sys.time() - now, 4), ", Receptor: ", i, " of ", n, ", Laeq16: ", round(laeq16, 4), " %%%%%%", sep = "")) 
  }
  ##Save to new shapefile
  dbSendQuery(con, "drop table if exists output")
  q <- paste("create table output as select st_x(r.geom), st_y(r.geom), d.* from noise as d left join ", receptors, " as r on d.rec_id = r.", rec_id, sep = "")
  rs <- dbSendQuery(con, q)
  
  pth <- paste(d, "\\TRANEX_out.csv", sep = "") 
  q <- paste("copy output to '", pth, "' delimiter ',' csv header", sep = "")
  rs <- dbSendQuery(con, q)
  
  dbDisconnect(con)
  
  file.remove(dir(d, full.names = TRUE))
  
  print(paste("OUTPUT IN: ", pth, sep =""))
  print(paste("TIME ELAPSED: ", Sys.time() - stt, sep=""))
  print("##### FINISHED #####")
}
