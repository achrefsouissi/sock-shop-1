package main

import (
	"fmt"
	"github.com/otaviokr/topological-sort/toposort"
)

func main() {
	// Mapping des nœuds aux noms des workloads
	workloadMapping := map[string]string{
		"0": "front-end-v1",
		"1": "orders",
		"2": "payment",
		"3": "catalogue",
		"4": "user",
		"5": "shipping",
		"6": "queue-master",
		"7": "rabbitmq",
		"8": "carts-db",
		"9": "catalogue-db",
		"10": "user-db",
		"11": "orders-db",
		"12": "shipping-db",
	}

	// Dépendances entre workloads
	unsorted := map[string][]string{
		"0": {"3", "1", "2"},
		"1": {"11"},
		"2": {"10"},
		"3": {"9"},
		"4": {},
		"5": {"6"},
		"6": {"7"},
		"7": {},
		"8": {},
		"9": {},
		"10": {},
		"11": {},
		"12": {},
	}

	// Tri topologique avec Kahn's algorithm
	sorted, err := toposort.KahnSort(unsorted)
	if err != nil {
		panic(err)
	}
	fmt.Printf("Result by Kahn's: ")
	for _, index := range sorted {
		fmt.Printf("%s ", workloadMapping[index])
	}
	fmt.Println()

	// Tri topologique avec Tarjan's algorithm
	sorted, err = toposort.TarjanSort(unsorted)
	if err != nil {
		panic(err)
	}
	fmt.Printf("Result by Tarjan's: ")
	for _, index := range sorted {
		fmt.Printf("%s ", workloadMapping[index])
	}
	fmt.Println()

	// Résultat inversé de Kahn's
	reversedKahn, err := toposort.ReverseKahn(unsorted)
	if err != nil {
		panic(err)
	}
	fmt.Printf("Reversed Kahn result: ")
	for _, index := range reversedKahn {
		fmt.Printf("%s ", workloadMapping[index])
	}
	fmt.Println()

	// Résultat inversé de Tarjan's
	reversedTarjan, err := toposort.ReverseTarjan(unsorted)
	if err != nil {
		panic(err)
	}
	fmt.Printf("Reversed Tarjan result: ")
	for _, index := range reversedTarjan {
		fmt.Printf("%s ", workloadMapping[index])
	}
	fmt.Println()
}

