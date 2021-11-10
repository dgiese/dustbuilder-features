#!/usr/bin/env sh
rm -rf ./root-dir
for f in ./*.deb
do
dpkg -x "$f" ./root-dir
done
rm -rf ./etc
rm -rf ./root-dir/usr/share
chmod +x ./root-dir/* -R
