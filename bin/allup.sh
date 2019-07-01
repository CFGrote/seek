#!/bin/bash

bundle exec rake sunspot:solr:start
bundle exec rake seek:workers:start
soffice --headless --accept="socket,host=127.0.0.1,port=8100;urp;" --nofirststartwizard > /dev/null 2>&1 &
bundle exec rails server --binding 0.0.0.0 --port 3000
