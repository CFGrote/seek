#!/bin/bash

bundle exec rake seek:workers:stop
bundle exec rake sunspot:solr:stop
killall -15 soffice
