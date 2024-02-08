# Enhanced Preprints Image Server

This project contains the files needed to build a docker image of the
[Cantaloupe image server](https://cantaloupe-project.github.io/) for the enhanced-preprints project. It is mostly build
files and some default configuration for running locally.

## Prerequisites

- docker
- Make

## Building the docker image

Run `make build`

## Running the docker image

Run the build first, then `make run` and visit http://localhost:8182/

## Docker compose for development

Run `docker compose up --wait`

Visit: http://localhost:8182/

A sample image should be available at http://localhost:8182/iiif/2/515698v2_fig1.tif/full/full/0/default.jpg
