# Ballerina Assignment - REST API and gRPC

```
library-system/       Question 1 - REST API
  Ballerina.toml
  types.bal
  service.bal
  web/index.html        (bonus web UI)
  client/
    Ballerina.toml
    client.bal

rental-system/         Question 2 - gRPC
  Ballerina.toml
  proto/rental.proto
  service.bal
  client/
    Ballerina.toml
    client.bal
```

## Needed

- Ballerina Swan Lake (`bal version` to check)
- `bal tool pull grpc` once, before generating gRPC stubs

## Question 1

```
cd library-system
bal run
```

Then in another terminal:

```
cd library-system/client
bal run
```

Or open `library-system/web/index.html` in a browser (needs the API running).

## Question 2

```
cd rental-system
bal grpc --input proto/rental.proto --output .
bal run
```

Then in another terminal:

```
cd rental-system/client
bal grpc --input ../proto/rental.proto --output .
bal run
```
