# QUL docker deployment

build the image:
```
docker build -t quranic-universal-library .
```
run it:

```
docker run --rm -it -p 3000:3000 --env RAILS_MASTER_KEY=<content of config/master.key> quranic-universal-library
```