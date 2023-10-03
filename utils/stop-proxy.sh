#!/bin/bash

ps | grep 'start-proxy' | awk '{print $1}' | xargs kill -9 > /dev/null 2>&1
ps | grep 'kubectl' | awk '{print $1}' | xargs kill -9 > /dev/null 2>&1

./caddy stop

exit 0