library(rasterVis)
library(data.table)
library(rgdal)
library(maptools)

setwd("/agmesh-scenarios/scenario_52177/summaries")
combined.df <- data.frame(read.csv("2001_2015_usda_gridmet_WA"))

#-remove all other variables to allow for datasets based on year, month, county, and commodity - loss and acres
combined.df2 <- subset(combined.df, select = -c(insuranceplancode,insurancename,stagecode,damagecausecode,damagecause,month,statecode,state,countyfips,countycode,bi,pr,th,pdsi,pet,erc,rmin,rmax,tmmn,tmmx,srad,sph,vs,fm1000,fm100) )

combined.df <- subset(combined.df, select = -c(commodity,insuranceplancode,insurancename,stagecode,damagecausecode,damagecause,month,statecode,state,countyfips,countycode,bi,pr,th,pdsi,pet,erc,rmin,rmax,tmmn,tmmx,srad,sph,vs,fm1000,fm100) )

#-convert to a data table

combined.df <- data.table(combined.df)

#-order the columns by commodity, then year, month, and county

combined.df <- combined.df[with(combined.df, order(commoditycode,year,monthcode,county)), ]

#-sum the acres and loss columns for all common rows  This merges all rows that have the same values exept for acres and loss.  We sum those to create a geographic
#-representation for each commodity - for each county, year, and month.  This will be use to convert to a raster for comparison to meterological data.

combined.df <- combined.df[, lapply(.SD, sum), by=list(year,county,commoditycode,monthcode)]

#--replacing commoditycode with commodity name

profession.code <- c(Apples=54, Wheat=11, Barley=91, SugarBeets=39, Cherries=57, Grapes=53, AdjustedGrossRevenue=63, 
                     GreenPeas=64, AllOtherCrops=99, Pears=89, Canola=15, SweetCorn=42, Mint=74, Potatoes=84, 
                     DryPeas=67, ProcessingBeans=46, DryBeans=47, Onions=13, Cranberries=58, Corn=41, 
                     Oats=16, AlfalfaSeed=107, FreshApricots=218, FresFreestonePeaches=223, Nursery=73, 
                     Mustard=69, Bluberries=12, AdjustedGrossRevenuelite=61, Plums=92, Soybeans=81, 
                     WholeFarmRevenueProtection=76, Buckwheat=114)

combined.df$commodity <- names(profession.code)[match(combined.df$commoditycode, profession.code)]
#-----




combined.yearmonth <- split(combined.df,list(combined.df$year,combined.df$monthcode, combined.df$commodity))
setwd("/agmesh-scenarios/scenario_52177/month/")
lapply(names(combined.yearmonth), function(funct){write.csv(combined.yearmonth[[funct]], file = paste(funct, ".csv", sep = ""))})

#--bringing in county shapefile
setwd("/nethome/erichs/counties/")

counties <- readShapePoly('UScounties.shp', 
                          proj4string=CRS
                          ("+proj=longlat +datum=WGS84 +ellps=WGS84 +towgs84=0,0,0"))
projection = CRS("+proj=longlat +datum=WGS84 +ellps=WGS84 +towgs84=0,0,0")

#counties <- counties[grep("Idaho|Washington|Oregon|Montana", counties@data$STATE_NAME),]
counties <- counties[grep("Washington", counties@data$STATE_NAME),]

unique <- list.files("/agmesh-scenarios/scenario_52177/month/")
maskraster <- raster("/agmesh-scenarios/scenario_52177/netcdf/pdsi_apr_1997.nc")

for (i in unique) {
  setwd("/agmesh-scenarios/scenario_52177/month/")
  x <- as.data.frame(read.csv(i, strip.white = TRUE))
  u <- data.frame(trimws(x$county, "r"))
  colnames(u) <- c("NAME")
  colnames(x) <- c("UNIQUEID", "YEAR", "COUNTY", "COMMODITYCODE", "MONTHCODE", "ACRES", "LOSS", "COMMODITY")
  z <- cbind(x,u)
  m <- merge(counties, z, by='NAME')
  #shapefile(m)
  extent(maskraster) <- extent(m)
  r <- rasterize(m, maskraster)
  i = substr(i,1,nchar(i)-4)
  setwd("/agmesh-scenarios/scenario_52177/raster_commodity/")
  writeRaster(r, filename=paste(i, "_raster", sep=""))
  setwd("/agmesh-scenarios/scenario_52177/raster_commodity_plots/")
  jpeg(paste(i, "_plot", sep=""))
  ramp <- colorRamp(c("blue", "red"))
  print(levelplot(r, att='LOSS', main=i, col.regions=rgb(ramp(seq(0, 1, length = 1000)), max = 255)) + layer(sp.polygons(m, lwd=0.5)))
  dev.off()
}

