-- ClickStack Simple Initialization Script
-- Creates the essential prometheus TimeSeries table for remote write

-- Create otel database if it doesn't exist
CREATE DATABASE IF NOT EXISTS otel;

-- Enable TimeSeries experimental feature
SET allow_experimental_time_series_table = 1;

-- Create TimeSeries table for Prometheus remote write
-- This is the only table needed for remote_write to work
CREATE TABLE IF NOT EXISTS otel.prometheus
ENGINE = TimeSeries;