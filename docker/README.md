# QUL docker deployment

Build the image:
```
docker build -t quranic-universal-library .
```

Run it:
```
docker run --rm -it -p 3000:3000 --env RAILS_MASTER_KEY=<content of config/master.key> quranic-universal-library
```

## Build Notes

The Docker build process automatically generates a temporary SECRET_KEY_BASE during asset precompilation. This resolves Rails 7.x validation requirements for production environment secret keys during the build process.