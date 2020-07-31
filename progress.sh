#!/usr/bin/env bash
installProgress=3
totalProgress=10



init(){
    progress 1 2
}
init

# ps -ef|grep -v grep|grep sleep|awk '{print $3}'|xargs kill -9
