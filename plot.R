d <- read.csv('database/song.db', header=FALSE, stringsAsFactors=FALSE)
names(d) <- c("AIRED","ARTIST","SONG","YEAR","PROP_NAME","AID")
years <- seq(min(d$YEAR),max(d$YEAR))
xs <- vector('numeric', length(years))
agg <- aggregate(d$YEAR, by=list(YEAR=d$YEAR), FUN=length)
idx <- match(agg$YEAR, years)
xs[idx] <- agg$x
prefix <- format(Sys.time (), "%Y-%m-%d")

fname <- sprintf("results/%s-year-radio1045.pdf", prefix)
pdf(file=fname, width=11, height=8.5)
barplot(xs, names.arg=years, las=2,
        main=sprintf("Radio 1045 Artist/Song by Year (%d samples)\nCollected: %s", 
                     length(d$SONG), date()))
dev.off ()

# the 90s should precede 2000+ so we need the century for sorting purposes
d$CENT <- d$YEAR %/% 100
d$DECADE <- ((d$YEAR %% 100) %/% 10) * 10
agg <- aggregate(d$DECADE, by=list(DECADE=d$DECADE, CENT=d$CENT), FUN=length)
agg <- agg[order(agg$CENT, agg$DECADE),]

fname <- sprintf("results/%s-decade-radio1045.pdf", prefix)
pdf(file=fname, width=11, height=8.5)
barplot(agg$x, names.arg=sprintf("%02ds", agg$DECADE),
        main=sprintf("Radio 1045 Artist/Song by Decade (%d samples)\nCollected: %s", 
                     length(d$SONG), date()))
dev.off ()


