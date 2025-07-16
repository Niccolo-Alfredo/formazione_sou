#!/bin/bash

# Attraverso questo piccolo script possiamo analizzare in modo continuo su terminale ssh dei singoli nodi
# la situazione dei docker e vedere se sono attivi o no.

while true; do
  clear
  docker ps
  sleep 1
done
