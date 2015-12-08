OS=$(uname)
if [[ $OS == "Darwin" ]]; then cd build/darwin; else cd build/linux; fi

REPO=https://github.com/heroku/ruby-sample.git
echo "start sources clonning ruby app"
./dockerizer buildpack sources "$REPO"
echo "try to detect technology"
./dockerizer buildpack detect
echo "try to build"
./dockerizer buildpack build "test-ruby"
echo "start cleanup system"
./dockerizer buildpack cleanup "test-ruby"

echo "start sources clonning ruby-rails app"
./dockerizer buildpack sources https://github.com/heroku/ruby-rails-sample.git
echo "try to detect technology"
./dockerizer buildpack detect
echo "try to build"
./dockerizer buildpack build "test-ruby"
echo "start cleanup system"
./dockerizer buildpack cleanup "test-ruby"
cd -

