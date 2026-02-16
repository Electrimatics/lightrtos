#!/bin/bash

wait_for_port() {
    port=$1
    until nc -z localhost $port
    do
        sleep 0.1
    done
}