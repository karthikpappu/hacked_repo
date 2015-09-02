#!/bin/sh

base_dir=$(cd "$(dirname "$1")"; pwd)/$(basename "$1")
build_dir=${base_dir}/build
jenkins_dir=${build_dir}/jenkins
mkdir -p ${jenkins_dir}/jobs

ls -1 ${build_dir}/jobs | while read xml_file
do
    name=$(echo $xml_file | cut -d'.' -f1)
    echo "Creating job... $name"
    mkdir -p ${jenkins_dir}/jobs/${name}
    cp $build_dir/jobs/$xml_file  ${jenkins_dir}/jobs/${name}/config.xml
done

# more info at https://wiki.intuit.com/x/gwaxE
docker run -p 8080:8080 -v ${jenkins_dir}/jobs:/var/jenkins_home/jobs jenkins
