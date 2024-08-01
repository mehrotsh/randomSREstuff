#!/bin/bash

# Fetch all PAC resources across all namespaces
kubectl get prometheusrules --all-namespaces -o json | jq -c '.items[]' | while read -r pac; do
    namespace=$(echo "$pac" | jq -r '.metadata.namespace')
    name=$(echo "$pac" | jq -r '.metadata.name')
    
    rules=$(echo "$pac" | jq -r '.spec.rules')
    updated_rules=$(echo "$rules" | jq 'map(if .description then .description |= sub("[.]?$"; ".") else . end)')

    # Create a temporary JSON file with the updated PAC
    tmpfile=$(mktemp)
    echo "$pac" | jq --argjson rules "$updated_rules" '.spec.rules = $rules' > "$tmpfile"

    # Apply the updated PAC
    kubectl apply -f "$tmpfile" -n "$namespace"

    echo "Updated PAC $name in namespace $namespace"
    rm "$tmpfile"
done
