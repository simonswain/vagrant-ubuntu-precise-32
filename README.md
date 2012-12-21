Create and install Ubuntu 12.04 server Vagrant base box.

## Install

This initial version is tested and working on Ubuntu Desktop 12.10.
Swap in the "headless" lines to run it on Ubuntu server.

A few packages are required

        $ sudo ./apt.sh

## Usage

       $ ./build.sh


This will download the Ubuntu 12.04 server ISO, create a VM
ubuntu-precise-32, package and install a Vagrant base box of the same
name. Any existing VM and base box with that name will be deleted
first.

## About

This is my take on [cal/vagrant-ubuntu-precise-64](https://github.com/cal/vagrant-ubuntu-precise-64)