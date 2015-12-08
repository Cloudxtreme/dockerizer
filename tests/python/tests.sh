OS=$(uname)
if [[ $OS == "Darwin" ]]; then cd build/darwin; else cd build/linux; fi

REPO=https://github.com/heroku/python-django-sample.git
echo "start sources clonning python app"
./dockerizer buildpack sources "$REPO"
echo "try to detect technology"
./dockerizer buildpack detect
echo "try to build"
./dockerizer buildpack build "test-python"
echo "start cleanup system"
./dockerizer buildpack cleanup "test-python"

cd -

