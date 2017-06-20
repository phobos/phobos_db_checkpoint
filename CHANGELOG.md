# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## 3.1.0 (2017-06-19)

- [enhancement] Add support for erb syntax in database config file

## 3.0.0 (2017-03-21)

- [enhancement] Remove endpoint for retrying events

## 2.4.0 (2017-03-13)

- [enhancement] Add endpoint for retrieving the number of failures

## 2.3.1 (2017-03-11)

- [bugfix] Add index required for current implementation of Phobos Checkpoint UI

## 2.3.0 (2017-03-08)

- [enhancement] Add created_at to events table

## 2.2.0 (2017-03-08)

- [enhancement] Add delete failure end point

## 2.1.0 (2017-03-07)

- [enhancement] When retrying failures, an event is created if they return an ack

## 2.0.0 (2017-03-01)

- [enhancement] Rename tables

## 1.1.0 (2017-02-28)

- [feature] Add end point for fetching individual failures

## 1.0.0 (2017-02-24)

- [feature] Introduce failures and failure handling in Handler. Add failures to the events API

## 0.5.0 (2016-12-28)

- [feature] Add another instrumentation to wrap the entire around consume

## 0.4.0 (2016-12-28)

- [feature] Add more instrumentation for consuming
- [feature] Support custom db config path

## 0.3.0 (2016-10-10)

- [feature] Built-in sinatra APP with events API

## 0.2.0 (2016-09-06)

- [feature] New CLI command to generate migrations #6
- [feature] Automatically sets database pool size based on listeners max_concurrency #2

## 0.1.1 (2016-09-02)

- [bugfix] Handler is not injecting start and stop methods #4

## 0.1.0 (2016-08-29)

- Published on Github
