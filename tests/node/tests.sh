OS=$(uname)
if [[ $OS == "Darwin" ]]; then cd build/darwin; else cd build/linux; fi

echo "start sources clonning"
./dockerizer buildpack sources https://sevchik403@bitbucket.org/Marshrutik/server.git master
echo "try to detect technology"
./dockerizer buildpack detect
echo "try to build"
./dockerizer buildpack build "test-node-plain"
echo "try to run"
id=$(docker run -d "test-node-plain")
echo "wait to stop"
sleep 10;
echo "get log"
docker logs $id
echo "stop container"
docker stop $id
echo "start cleanup system"
./dockerizer buildpack cleanup "test-node-plain"

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
