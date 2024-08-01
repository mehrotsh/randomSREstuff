#!/bin/bash

# Fetch all PAC resources across all namespaces
kubectl get prometheusrules --all-namespaces -o json | jq -c '.items[]' | while read -r pac; do
    namespace=$(echo "$pac" | jq -r '.metadata.namespace')
    name=$(echo "$pac" | jq -r '.metadata.name')

    groups=$(echo "$pac" | jq -r '.spec.groups')
    updated_groups=$(echo "$groups" | jq 'map(
        .rules |= map(
            if .description then .description |= sub("[.]?$"; ".") else . end
        )
    )')

    # Create a temporary JSON file with the updated PAC
    tmpfile=$(mktemp)
    echo "$pac" | jq --argjson groups "$updated_groups" '.spec.groups = $groups' > "$tmpfile"

    # Apply the updated PAC
    kubectl apply -f "$tmpfile" -n "$namespace"

    echo "Updated PAC $name in namespace $namespace"
    rm "$tmpfile"
done
