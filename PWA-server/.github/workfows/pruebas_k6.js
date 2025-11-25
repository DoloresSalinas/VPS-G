name: Pruebas de Carga K6

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  k6-test:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout del repositorio
        uses: actions/checkout@v3

      - name: Instalar K6
        run: |
          sudo apt-get update
          sudo apt-get install -y k6

      - name: Ejecutar pruebas en K6 Cloud
        env:
          K6_CLOUD_TOKEN: ${{ secrets.K6_CLOUD_TOKEN }}
        run: k6 cloud pruebas_k6.js
