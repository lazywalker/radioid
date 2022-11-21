#
# Copyright 2020 Michael BD7MQB <bd7mqb@qq.com>
# This is free software, licensed under the GNU GENERAL PUBLIC LICENSE, Version 3.0
#
# For macOS:
# brew install tarantool
#

USERCSV=./download/user.csv
DMRIDS=./export/DMRIds.dat

all:
	@echo "Avaliable commands:\n"
	@echo "make dl		- Download the latest user.csv from radioid.net"
	@echo "make build	- Build CountryCode.txt and DMRIds.dat using user.csv"
	
dl:
	@echo "Downloading user.csv ..."
	@curl --progress-bar https://database.radioid.net/static/user.csv -o ${USERCSV}
	@echo "Done."

build:
	@./radioid.lua
	@gzip -f -k ${DMRIDS}

sync:
	rsync -avz --delete --exclude='.*' --delete-excluded export/* ostar:/var/www/ostar/radioid/
