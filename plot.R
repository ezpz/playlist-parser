d <- read.csv('database/song.db', header=FALSE, stringsAsFactors=FALSE)
names(d) <- c("AIRED","ARTIST","SONG","YEAR","PROP_NAME","AID")
years <- seq(min(d$YEAR),max(d$YEAR))
xs <- vector('numeric', length(years))
agg <- aggregate(d$YEAR, by=list(YEAR=d$YEAR), FUN=length)
idx <- match(agg$YEAR, years)
xs[idx] <- agg$x
fname <- sprintf("results/%s-radio1045.pdf", format(Sys.time (), "%Y-%m-%d"))
pdf(file=fname, width=11, height=8.5)
barplot(xs, names.arg=years, las=2,
        main=sprintf("Radio 1045 Artist/Song by Year (%d samples)\nCollected: %s", 
                     length(d$SONG), date()))
dev.off ()
