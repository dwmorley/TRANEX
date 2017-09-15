###################################################
## Copyright 2014-15 David Morley
## 
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
## 
##     http://www.apache.org/licenses/LICENSE-2.0
## 
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.
###################################################
###################################################
## TRANEX Road Traffic Noise Model
## Version 1.3
##
## For instructions see the ReadMe
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

## R Packages required
require(RPostgreSQL)
require(sp)
require(rgrass7) 
require(maptools)
require(rgdal)

##Get model
setwd("P:\\Noise\\Current\\tranex") #Path to TRANEX model files
source('tranexSource_R.r')

##Specify your postgres connection here
##Postgres connection string: host, port, database, user, password
conn <- c('localhost', '5432', 'tranextest', 'postgres', '******')

##Input data (names are postgres tables, no extensions or paths)
receptors <- "receptors"    	      #[Receptors]
rec_id <- "gid"			        #[Receptor id field]
roads <- "ne_10m_points_clip"		            #[10m road segment points [rd_node_id]]
land <- "mm_bh_ne_clip"				        #[Landcover polygons]
flow <- "traffic08_ne_clip" 	              #[Traffic dbf: v, q, p [rd_node_id]]
reflect <- TRUE		      #[Logical do reflections]
heights <- "rat"			        #[Building heights raster for reflections]
nodes <- "ne_node50_clip"		          	#[Building polygon nodes for reflections]

##Run the function, this does all the processing
run_crtn(conn, receptors, rec_id, roads, land, flow, reflect, heights, nodes)



