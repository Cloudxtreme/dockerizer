OS=$(uname)
if [[ $OS == "Darwin" ]]; then cd build/darwin; else cd build/linux; fi

echo "start sources clonning"
./dockerizer buildpack sources https://sevchik403@bitbucket.org/Marshrutik/server.git master
echo "try to detect technology"
./dockerizer buildpack detect
echo "try to build"
./dockerizer buildpack build "test-node-plain"
echo "start cleanup system"
#./dockerizer buildpack cleanup "test-node-plain"

sleep 3;
echo "start sources clonning"
./dockerizer buildpack sources https://github.com/undassa/node-hello-world.git
echo "try to detect technology"
./dockerizer buildpack detect
echo "try to build"
./dockerizer buildpack build "test-node"
echo "start cleanup system"
./dockerizer buildpack cleanup "test-node"
cd -
