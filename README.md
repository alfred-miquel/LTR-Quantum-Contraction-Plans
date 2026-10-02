# Learning-to-Rank-Tensor-Network-Contraction-Plans-for-GPU-Accelerated-Quantum-Circuit-Simulation

This repository contains the code, data, trained models, and analysis notebooks supporting the results presented in:

*Pastor, A. M., Castillo, M., & Badía, J. M. (2026). Learning to Rank Tensor Network Contraction Plans for GPU-Accelerated Quantum Circuit Simulation. arXiv preprint arXiv:2608.05819.*

The repository includes the circuit instances, candidate contraction plans, measured execution times, feature-extraction scripts, trained models, and analysis code used to obtain the results reported in the paper.



## Contents

### `src`
The `src` directory contains the software implementation of the article using Julia as a programming language. This code is employed to generate and analyze contraction plans.


### `Data`
This directory contains all the data used in the article split into various subdirectories: circuit instances, contraction plans, measured execution times,
  and derived features used in the experiments.

### `Jupyter Notebooks`
Various commented Jupyter notebooks are provided to test the algorithms and replicate experimental results included in the article. These notebooks guide users through setting up and running the experiments step by step.

### `models`
Some XGBoost models are stored in this directory
## Prerequisites

To test the code, ensure the following software is installed:

1. **Julia**
   - Download and install Julia from [https://julialang.org/](https://julialang.org/).
  All the software tested in this repository has been executed using the **Julia Version 1.9.1**
2. **Python** (for running the Jupyter notebooks)
   - Install Python from [https://www.python.org/](https://www.python.org/).
   - Install Jupyter Notebook by running:
     ```bash
     pip install notebook
     ```

> **Note:** There is no need to preinstall QXTools or other related packages. The required packages can be installed interactively within the Julia environment when running the code or via the provided Jupyter notebooks.

## Quick Start Example

Here is a simple "Hello World" example to run the code on a GHZ circuit of a specific size.

### Julia Code Example

```julia
# Create a project
]activate New_Project_on_QXTools;

# Add necessary packages
import Pkg; 
Pkg.add("QXTools")
Pkg.add("QXGraphDecompositions")
Pkg.add("QXZoo")
Pkg.add("DataStructures")
Pkg.add("QXTns")
Pkg.add("NDTensors")
Pkg.add("ITensors")
Pkg.add("LightGraphs")
Pkg.add("PyCall")


# Using required modules
using QXTools
using QXTns
using QXZoo
using PyCall
using QXGraphDecompositions
using LightGraphs
using DataStructures
using TimerOutputs
using ITensors
using LinearAlgebra
using NDTensors

# checking the Julia version
 VERSION
# more information
versioninfo()
# Load custom functions from the folder src
include("../src/funcions_article_IA.jl");

# Create a GHZ circuit with 10 qubits
circuit = create_ghz_circuit(10)

# Convert the circuit to a tensor network circuit (TNC)
tnc = convert_to_tnc(circuit)

# Getting a contraction plan
 plan = min_fill_contraction_plan(tnc)

# Print results
println("Getting a plan completed. Results:")
println(plan)
```

### Running the Code
Save the above code in a file, e.g., `run_example.jl`. Then, run the file from the Julia REPL, using the -t auto option to be able to use threads:

```bash
julia -t auto run_example.jl
```

## Using Jupyter Notebooks

To explore the algorithms further, open one of the provided notebooks:

1. Navigate to the `notebooks` directory.
2. Launch the Jupyter Notebook server:
   ```bash
   jupyter notebook
   ```
   Although you can use ```IJulia``` from Julia REPL. Please visit [here](https://julialang.github.io/IJulia.jl/stable/manual/installation/):
   ```
   using IJulia
   notebook()
    ```
    This action launchs the IJulia notebook in your browser.
4. Open a notebook and follow the instructions provided.

---

We hope this repository provides valuable resources for exploring and experimenting with the article's code!

## License

The source code in this repository is released under the MIT License.

The datasets and experimental results contained in the `Data` directory
are released under the Creative Commons Attribution 4.0 International
(CC BY 4.0) license.

