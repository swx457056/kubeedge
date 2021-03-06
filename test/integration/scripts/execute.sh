#!/bin/bash

# Copyright 2019 The KubeEdge Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

workdir=`pwd`
cd $workdir

curpath=$PWD
echo $PWD

modulename=$1
#run the edge_core bin to run the integration
go build cmd/edge_core.go
#dynamically append testManager Module before starting integration test.
sed -i 's/dbTest/dbTest, testManager/g' conf/modules.yaml
#restart edge_core after appending testManager Module.
pkill edge_core
nohup ./edge_core > edge_core.log 2>&1 &
sleep 15s
if pgrep edge_core >/dev/null
then
    echo "edge_core process is Running"
else
    echo "edge_core process is not started"
    exit 1
fi

PWD=${curpath}/test/integration
sudo rm -rf $PWD/modules/edgecore/$modulename/$modulename.test
sudo apt-get install -y golang-ginkgo-dev
# Specify the module name to compile in below command
ginkgo build -r $PWD/modules/edgecore/$modulename
export MQTT_SERVER=127.0.0.1
:> /tmp/testcase.log
sudo bash ${PWD}/scripts/fast_test $modulename 2>&1 | tee /tmp/fast_test.log && cat /tmp/fast_test.log >> /tmp/testcase.log && :> /tmp/fast_test.log
sed -i 's/dbTest, testManager/dbTest/g' conf/modules.yaml
grep  -e "Running Suite" -e "SUCCESS\!" -e "FAIL\!" /tmp/testcase.log | sed -r 's/\x1B\[([0-9];)?([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g' | sed -r 's/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g'
echo "Integration Test Final Summary Report"
echo "==============================================="
echo "Total Number of Test cases = `grep "Ran " /tmp/testcase.log | awk '{sum+=$2} END {print sum}'`"
passed=`grep -e "SUCCESS\!" -e "FAIL\!" /tmp/testcase.log | awk '{print $3}' | sed -r "s/\x1B\[([0-9];)?([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g" | awk '{sum+=$1} END {print sum}'`
echo "Number of Test cases PASSED = $passed"
fail=`grep -e "SUCCESS\!" -e "FAIL\!" /tmp/testcase.log | awk '{print $6}' | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g" | awk '{sum+=$1} END {print sum}'`
echo "Number of Test cases FAILED = $fail"
echo "==================Result Summary======================="
if [ "$fail" != "0" ];then
    echo "Integration suite has failures, Please check !!"
    exit 1
else
    echo "Integration suite successfully passed all the tests !!"
    exit 0
fi
