###################################################
## TRANEX Road Traffic Noise Model
##
## For reference see:
##
## John Gulliver, David Morley, Danielle Vienneau, Federico Fabbri, Margaret Bell, 
## Paul Goodman, Sean Beevers, David Dajnak, Frank J Kelly, Daniela Fecht, 
## Development of an open-source road traffic noise model for exposure assessment, 
## Environmental Modelling & Software 
## Available online 8 January 2015, 
## ISSN 1364-8152, http://dx.doi.org/10.1016/j.envsoft.2014.12.022.
## (http://www.sciencedirect.com/science/article/pii/S136481521400379X)
##
## MRC-PHE Centre for Environment and Health 
## Department of Epidemiology and Biostatistics
## School of Public Health, Faculty of Medicine
## Imperial College London, UK
## 
## Contact:    			 
## David Morley: d.morley@imperial.ac.uk	 
###################################################


### SETUP ###

SETUP GRASS
Download the 32-bit (even if 64-bit PC) version of GRASS 7.0.4 from, http://trac.osgeo.org/osgeo4w/
(There was a bug with the viewshed function in GRASS 7.0.3)
Choose the quickstart version
Select to install GRASS package only, not QGIS etc
You may have to adjust the GRASS path (initGRASS) in the file tranexSource_R (use a text editor)

SETUP R
Use R version >= 3.0.0 from, http://cran.r-project.org/
Install packages: RPostgreSQL, sp, rgdal, spgrass, maptools
You may have to set the "R_LIBS" environmental variable to match '.libPaths()' for PostGIS to work
It is recommended to run tranex in R via RStudio, http://www.rstudio.com/

SETUP POSTGRESQL
Download >=v9.4 from http://www.postgresql.org as enterpriseDB installer
Once installed, launch stackbuilder
Select spatial add-ons > postgis
Make sure you select 'create spatial database'

SETUP POSTGIS DATABASE
Ensure database is created using the postgis template
Ensure all input files are correctly imported/named into created database using the PostGIS Shapefile importer
Ensure all files have the correct SRID, eg: 27700 for the UK OS National Grid
Ensure all functions have been created by running tranex_postgres.sql in the created database

To import raster (Use tif format, not ArcGrid), use raster2pgsql.exe from command line, for example:
> raster2pgsql -s 27700 -I C:\myraster.tif -t 50x50 public.myraster > C:\temp\myraster.sql
> psql -U postgres -d CRTN -f C:\temp\myraster.sql
When imported: in pgAdminIII, right-click myraster > maintainence > Vacuum Analyze
Sometimes using files on network drives won't work, use C: instead.
raster2pgsql can be found in the postgres bin directory

### RUNNING ###

Run from the run_crtn() function in R. This will do all the processing and calls to PostGIS/GRASS
Lots of messages are generated. If the model keeps running it is ok to ignore these.
Receptors processed point-by-point. After each, viewshed is plotted and time taken is given
Output saved to CRTN postgres database in table 'output' and in R tempdir() as 'TRANEX_out.csv'
File permissions may mean csv cannot be saved. To output export directly from Postgres, use:
copy output to 'C:/Program Files/PostgreSQL/9.4/data/TRANEX_out.csv' delimiter ',' csv header;


### FILE FORMATS ###

Input data columns required

receptors: 
Geometry (point) [location of receptor]
id [unique ID of receptor, INT]

Roads:
Geometry (point) [location of point along road]
rd_node_id [unique ID of point, INT]

Land:
Geometry (polygon)
mm_id [unique ID of polygon, INT]
legend [landcover class, CHAR]

Note that the default landcover used in TRANEX is OS MasterMap
Other landcover data can be used, but the look-up table 'lut'
must be changed accordingly in the postgres script

Flow: (this is joined to the Road geometry by rd_node_id)
rd_node_id [unique ID of point, INT]
slope_per [% gradient of road segment, INT]
v_0 to v_23 [Traffic speed in km/h, NUMERIC] (NOTE: 24 columns)
p_0 to p_23 [Hourly Percentage of Heavy vehicles, NUMERIC] (NOTE: 24 columns)
q_0 to q_23 [Hourly traffic flow, NUMERIC] (NOTE: 24 columns)

Heights:
Geometry (raster) 
Attribute [building height in m]

Nodes:
Geometry (point) [location of building node, i.e polygon vertex]
node_id [unique ID of point, INT]
block_id [unique ID of building according to landcover data, INT]






