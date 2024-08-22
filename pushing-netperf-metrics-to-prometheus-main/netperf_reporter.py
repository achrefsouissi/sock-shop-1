#!/usr/bin/env python3

import argparse
import logging
import requests
import sys
import pandas as pd

# Configurer les logs
logging.basicConfig(level=logging.DEBUG, format='%(asctime)s %(message)s', datefmt='%m/%d/%Y %I:%M:%S %p')
file_handler = logging.FileHandler('netperf_reporter.log', mode='w')
file_handler.setFormatter(logging.Formatter('%(asctime)s %(message)s', datefmt='%m/%d/%Y %I:%M:%S %p'))
logging.getLogger().addHandler(file_handler)

# Parser les arguments de la ligne de commande
parser = argparse.ArgumentParser(description='Run netperf reporter...')
parser.add_argument('--file', default='results.csv', type=str, help='The .csv file with netperf measurements.')

args = parser.parse_args()

# Configuration de l'URL du PushGateway
PROMETHEUS_CONFIG = dict(
    URL="http://prometheus-pushgateway:9091/metrics/job/netperf/instance/networkAware",
    USR="",
    PSW=""
)

# Clés des métriques
keys = ["netperf_p50_latency_microseconds", "netperf_p90_latency_microseconds", "netperf_p99_latency_microseconds"]

def read_data(filename):
    """ Lire les données du fichier CSV et préparer les métriques """
    result = []
    try:
        df = pd.read_csv(filename)
        logging.info("Reading CSV file... Dataframe: ")
        logging.info(df)

        # Convertir les colonnes spécifiques en float et remplacer les NaN par 0
        for k in keys:
            if k in df.columns:
                df[k] = pd.to_numeric(df[k], errors='coerce').fillna(0)

        for ind, row in df.iterrows():
            for k in keys:
                value = row.get(k)
                if value != 0:  # Vérifier si la valeur n'est pas NaN ou 0
                    result.append(
                        ('{0}{{origin="{1}", destination="{2}"}}'.format(k, row['origin'], row['destination']), value))

        logging.info("Retrieved '{0}' metrics".format(len(result)))
    except Exception as e:
        logging.error("Failed to read CSV file: %s", str(e))
        sys.exit(1)

    return result

def push_to_prometheus(data):
    """ Envoyer les données au PushGateway """
    result = ""

    for k in keys:
        result += "{0}\n".format("# HELP " + k + " netperf measurement pushed to the Prometheus Pushgateway.")
        result += "{0}\n".format("# TYPE " + k + " gauge")

    for metric, value in data:
        metric_key = metric.replace(".", "_")
        result += "{0} {1}\n".format(metric_key, value)
        logging.info("Metric {0} has the value {1}".format(metric_key, value))

    logging.info("Metrics to be pushed:\n%s", result)

    try:
        req = requests.post(
            PROMETHEUS_CONFIG.get("URL"),
            data=result,
            auth=(PROMETHEUS_CONFIG.get("USR"), PROMETHEUS_CONFIG.get("PSW")),
            headers={'Content-Type': 'text/plain'}
        )
        
        logging.info("Response from PushGateway: %s", req.text)

        if req.status_code == 202:
            logging.info("Data pushed correctly to Prometheus")
            return True
        else:
            logging.error("Cannot push data to Prometheus: err='%s' status_code=%d", req.text, req.status_code)
            return False
    except requests.RequestException as e:
        logging.error("Exception occurred while sending request: %s", str(e))
        return False

def main():
    logging.info("Script started with arguments: %s", args)

    csv = args.file

    if csv == "":
        logging.error("CSV file to retrieve data is not defined.")
        sys.exit(1)

    data = read_data(csv)

    if len(data) == 0:
        logging.error("No data was retrieved from CSV file...")
        sys.exit(1)

    push_to_prometheus(data)

if __name__ == "__main__":
    main()

