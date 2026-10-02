################################################################################
## QASM import / export utilities for QXZoo ↔ Qiskit interoperability
################################################################################

using PyCall

# Import Qiskit from Python
qiskit = pyimport("qiskit")

# aer = pyimport("qiskit_aer")


"""
    load_qasm_circuit(filename)

Load a quantum circuit from a QASM file using Qiskit's
`QuantumCircuit.from_qasm_file`.

# Arguments
- `filename::String`: path to the QASM file.

# Returns
- A Qiskit `QuantumCircuit` object.
"""
function load_qasm_circuit(filename)
    return qiskit.QuantumCircuit.from_qasm_file(filename)
end


## Adapt QWalk files so that they can be used in QXZoo by renaming the qubits

"""
    replace_qasm_registers(input_file::String, output_file::String="output.qasm")

Adapt QWalk QASM files so that they can be used in QXZoo by renaming the
`node` and `coin` registers into a single `q` register.

# Arguments
- `input_file::String`: path to the input QASM file.
- `output_file::String="output.qasm"`: path to the rewritten QASM file.

# Returns
- `new_content::String`: the rewritten QASM content.
"""
function replace_qasm_registers(input_file::String, output_file::String="output.qasm")
    # Read the file content
    content = read(input_file, String)

    # Build the substitution dictionary
    replacements = Dict{String,String}()

    # Process the register definitions
    node_count = 0
    coin_count = 0

    # Locate the register definitions
    for line in split(content, '\n')
        if occursin(r"qreg\s+node\[(\d+)\];", line)
            node_count = parse(Int, match(r"qreg\s+node\[(\d+)\];", line).captures[1])
        elseif occursin(r"qreg\s+coin\[(\d+)\];", line)
            coin_count = parse(Int, match(r"qreg\s+coin\[(\d+)\];", line).captures[1])
        end
    end

    # Build the substitution for `node`
    for i in 0:(node_count-1)
        replacements["node[$i]"] = "q[$i]"
    end

    # Build the substitution for `coin`
    for i in 0:(coin_count-1)
        replacements["coin[$i]"] = "q[$(i+node_count)]"
    end

    # Apply the substitutions
    new_content = content
    for (old, new) in replacements
        new_content = replace(new_content, old => new)
    end

    # Replace the register definitions
    if node_count > 0 || coin_count > 0
        total_qubits = node_count + coin_count
        new_content = replace(new_content,
                              r"qreg\s+node\[\d+\];\s*qreg\s+coin\[\d+\];" =>
                              "qreg q[$total_qubits];")
    end

    # Write the output file
    write(output_file, new_content)

    return new_content
end


## From a QASM file, obtain a QXZoo circuit

using QXZoo
using QXZoo.Circuit
using QXZoo.DefaultGates

"""
    import_from_qasm(filename::String)

Read a QASM file and build the corresponding `QXZoo.Circuit.Circ` object.

# Arguments
- `filename::String`: path to the QASM file.

# Returns
- `circ::QXZoo.Circuit.Circ`: the parsed circuit.
"""
function import_from_qasm(filename::String)
    # Read all lines of the file
    lines = readlines(filename)

    # Filter out irrelevant lines (comments and blanks)
    filtered_lines = filter(line -> !(startswith(strip(line), "//") ||
                                       startswith(strip(line), "#") ||
                                       isempty(strip(line))), lines)

    # Process the header
    num_qubits = 0
    circ = nothing
    for line in filtered_lines
        if occursin(r"^qreg q\[", line)
            num_qubits = parse(Int, match(r"qreg q\[(\d+)\];", line).captures[1])
            circ = QXZoo.Circuit.Circ(num_qubits)
            break
        end
    end

    if circ === nothing
        error("Could not determine the number of qubits from the QASM file")
    end

    # Process the gates
    for line in filtered_lines
        if occursin(r"^[a-z]", line)
            process_gate_line!(circ, line)
        end
    end

    return circ
end


"""
    export_to_qasm(circ, filename)

Write a `QXZoo.Circuit.Circ` object to a QASM 2.0 file.

Note: QXZoo indices are 1-based while QASM indices are 0-based, so the
qubit indices are decremented by one when writing.

# Arguments
- `circ`: the QXZoo circuit to export.
- `filename::String`: path to the output QASM file.
"""
function export_to_qasm(circ, filename)
    open(filename, "w") do f
        println(f, "OPENQASM 2.0;")
        println(f, "include \"qelib1.inc\";")
        println(f, "qreg q[", circ.num_qubits, "];")
        println(f, "creg c[", circ.num_qubits, "];")

        for gate in circ.:circ_ops

            if gate.gate_symbol.label == :x
                println(f, "x q[", gate.target - 1, "];")   # subtract because QXZoo is 1-based
                # println(f, "x q[", gate.target , "];")

            elseif gate.gate_symbol.label == :y
                println(f, "y q[", gate.target - 1, "];")
                # println(f, "y q[", gate.target , "];")

            elseif gate.gate_symbol.label == :z
                println(f, "z q[", gate.target - 1, "];")
                # println(f, "z q[", gate.target , "];")
            elseif gate.gate_symbol.label == :h
                println(f, "h q[", gate.target - 1, "];")
                # println(f, "h q[", gate.target , "];")
            elseif gate.gate_symbol.label == :s
                println(f, "s q[", gate.target - 1, "];")
                # println(f, "s q[", gate.target , "];")
            elseif gate.gate_symbol.label == :t
                println(f, "x q[", gate.target - 1, "];")   # NOTE: unchanged from original
                # println(f, "t q[", gate.target , "];")

            elseif gate.gate_symbol.label == :r_x      # rx(pi/2) q[1];
                println(f, "rx(", gate.gate_symbol.param, ") ", "q[", gate.target - 1, "];")
                # println(f, "rx (", gate.gate_symbol.param, ") ", "q[", gate.target, "];")

            elseif gate.gate_symbol.label == :r_y      # ry(pi/2) q[1];
                println(f, "ry(", gate.gate_symbol.param, ") ", "q[", gate.target - 1, "];")
                # println(f, "ry (", gate.gate_symbol.param, ") ", "q[", gate.target, "];")

            elseif gate.gate_symbol.label == :r_z      # rz(pi/2) q[1];
                println(f, "rz(", gate.gate_symbol.param, ") ", "q[", gate.target - 1, "];")
                # println(f, "rz (", gate.gate_symbol.param, ") ", "q[", gate.target, "];")

            elseif gate.gate_symbol.label == :c_x      # cx q[1], q[2];
                # println(f, "cx ", "q[", gate.ctrl, "],q[", gate.target, "];")
                println(f, "cx ", "q[", gate.ctrl-1, "],", "q[", gate.target-1, "];")

            elseif gate.gate_symbol.label == :c_y      # cy q[1], q[2];
                # println(f, "cy ", "q[", gate.ctrl, "],q[", gate.target, "];")
                println(f, "cy ", "q[", gate.ctrl-1, "],", "q[", gate.target-1, "];")

            elseif gate.gate_symbol.label == :c_z      # cz q[1], q[2];
                # println(f, "cz ", "q[", gate.ctrl, "],q[", gate.target, "];")
                println(f, "cz ", "q[", gate.ctrl-1, "],", "q[", gate.target-1, "];")

            elseif gate.gate_symbol.label == :swap
                println(f, "swap q[", gate.ctrl - 1, "],q[", gate.target - 1, "];")
                # println(f, "swap q[", gate.ctrl, "],q[", gate.target, "];")

            # Add more gates here if needed
            elseif gate.gate_symbol.label == :c_r_phase  # cp(pi/7) q[1], q[2];
                # println(f, "cp (", gate.gate_symbol.param, ") q[", gate.ctrl, "],q[", gate.target, "];")
                println(f, "cp (", gate.gate_symbol.param, ") q[", gate.ctrl - 1, "],q[", gate.target - 1, "];")
            else
                @warn "Unsupported gate: $(gate.name) — skipping"
            end
        end
    end
end


###########


# This function fixes the bug present in the previous version of the function:
# in Qiskit the order is control, target, whereas in QXZoo it is reversed.

"""
    process_gate_line_vell!(circ::QXZoo.Circuit.Circ, line::String)

Legacy version of `process_gate_line!` kept for reference. It parses a single
QASM gate line and appends the corresponding gate to the QXZoo circuit.

Note: the control/target order of two-qubit gates is reversed with respect to
Qiskit, matching QXZoo's convention.
"""
function process_gate_line_vell!(circ::QXZoo.Circuit.Circ, line::String)
    try
        # Remove leading and trailing whitespace
        line = strip(line)

        # Single-qubit, non-parametric gates
        if occursin(r"^x\s+q\[", line)
            qubit = parse(Int, match(r"x\s+q\[(\d+)\];", line).captures[1]) + 1
            Circuit.add_gatecall!(circ, x(qubit))

        elseif occursin(r"^y\s+q\[", line)
            qubit = parse(Int, match(r"y\s+q\[(\d+)\];", line).captures[1]) + 1
            Circuit.add_gatecall!(circ, y(qubit))

        elseif occursin(r"^z\s+q\[", line)
            qubit = parse(Int, match(r"z\s+q\[(\d+)\];", line).captures[1]) + 1
            Circuit.add_gatecall!(circ, z(qubit))

        elseif occursin(r"^h\s+q\[", line)
            qubit = parse(Int, match(r"h\s+q\[(\d+)\];", line).captures[1]) + 1
            Circuit.add_gatecall!(circ, h(qubit))

        elseif occursin(r"^s\s+q\[", line)
            qubit = parse(Int, match(r"s\s+q\[(\d+)\];", line).captures[1]) + 1
            Circuit.add_gatecall!(circ, s(qubit))

        elseif occursin(r"^t\s+q\[", line)
            qubit = parse(Int, match(r"t\s+q\[(\d+)\];", line).captures[1]) + 1
            Circuit.add_gatecall!(circ, t(qubit))

        # Single-qubit parametric gates (no space after the gate name)
        elseif occursin(r"^rx\(", line)
            m = match(r"rx\((.*)\)\s+q\[(\d+)\];", line)
            angle = eval(Meta.parse(m.captures[1]))   # allows expressions like pi/2
            qubit = parse(Int, m.captures[2]) + 1
            Circuit.add_gatecall!(circ, r_x(qubit, angle))

        # New search patterns for u2 and u1
        elseif occursin(r"^u2\(", line)
            pattern = r"u2\(([^,]+),\s*([^)]+)\)\s+q\[(\d+)\]"
            # Look for matches
            m = match(pattern, line)

            if m === nothing
                error("Invalid line format. Expected 'u2(angle1,angle2) q[qubit]'")
            end

            # Extract and convert the values
            angle1_str = m.captures[1]
            angle2_str = m.captures[2]
            qubit_str  = m.captures[3]

            # Parse the angles (may contain mathematical expressions like pi/2)
            angle1 = eval(Meta.parse(angle1_str))
            angle2 = eval(Meta.parse(angle2_str))

            # Convert the qubit to an integer
            qubit = parse(Int, qubit_str) + 1

            # Now build the corresponding gate
            phi = angle1
            lambda = angle2
            matriu = u2(phi, lambda)
            nova_porta_1q_u2 = create_gate_1q("nova_porta_1q_u2", u2(phi, lambda))
            circ << u(nova_porta_1q_u2, qubit)

        # New search patterns for u2 and u1
        elseif occursin(r"^u1\(", line)
            pattern = r"u1\(([^)]+)\)\s+q\[(\d+)\];"

            # Look for matches
            m = match(pattern, line)

            if m === nothing
                error("Invalid line format. Expected 'u1(angle) q[qubit];'")
            end

            # Extract and convert the values
            angle_str = m.captures[1]
            qubit_str = m.captures[2]

            # Parse the angle (may contain mathematical expressions like pi/2)
            angle = eval(Meta.parse(angle_str))

            # Convert the qubit to an integer
            qubit = parse(Int, qubit_str) + 1

            # Now build the corresponding gate
            phi = angle
            # lambda = angle2
            matriu = u1(phi)
            nova_porta_1q_u1 = create_gate_1q("nova_porta_1q_u1", u1(phi))
            circ << u(nova_porta_1q_u1, qubit)

        # New search pattern for the p gate
        elseif occursin(r"^p\(", line)
            pattern = r"p\(([^)]+)\)\s+q\[(\d+)\];"

            # Look for matches
            m = match(pattern, line)

            if m === nothing
                error("Invalid line format. Expected 'p(angle) q[qubit];'")
            end

            # Extract and convert the values
            angle_str = m.captures[1]
            qubit_str = m.captures[2]

            # Parse the angle (may contain mathematical expressions like pi/2)
            angle = eval(Meta.parse(angle_str))

            # Convert the qubit to an integer
            qubit = parse(Int, qubit_str) + 1

            # Now build the corresponding gate
            phi = angle
            # lambda = angle2
            matriu = p(phi)
            nova_porta_1q_p = create_gate_1q("nova_porta_1q_p", p(phi))
            circ << u(nova_porta_1q_p, qubit)

        elseif occursin(r"^sx\s+q\[", line)
            # Process sx (equivalent to rx(pi/2))
            m = match(r"sx\s+q\[(\d+)\];", line)
            angle = pi/2
            qubit = parse(Int, m.captures[1]) + 1
            # println("$angle, angle and qubit $qubit in the sx gate")
            Circuit.add_gatecall!(circ, r_x(qubit, angle))

        elseif occursin(r"^ry\(", line)
            m = match(r"ry\((.*)\)\s+q\[(\d+)\];", line)
            angle = eval(Meta.parse(m.captures[1]))
            qubit = parse(Int, m.captures[2]) + 1
            Circuit.add_gatecall!(circ, r_y(qubit, angle))

        elseif occursin(r"^rz\(", line)
            m = match(r"rz\((.*)\)\s+q\[(\d+)\];", line)
            angle = eval(Meta.parse(m.captures[1]))
            qubit = parse(Int, m.captures[2]) + 1
            Circuit.add_gatecall!(circ, r_z(qubit, angle))

        # Two-qubit, non-parametric gates
        elseif occursin(r"^cx\s+q\[", line)
            m = match(r"cx\s+q\[(\d+)\],\s*q\[(\d+)\];", line)
            ctrl = parse(Int, m.captures[1]) + 1
            target = parse(Int, m.captures[2]) + 1
            Circuit.add_gatecall!(circ, c_x(target, ctrl))

        elseif occursin(r"^cy\s+q\[", line)
            m = match(r"cy\s+q\[(\d+)\],\s*q\[(\d+)\];", line)
            ctrl = parse(Int, m.captures[1]) + 1
            target = parse(Int, m.captures[2]) + 1
            Circuit.add_gatecall!(circ, c_y(target, ctrl))

        elseif occursin(r"^cz\s+q\[", line)
            m = match(r"cz\s+q\[(\d+)\],\s*q\[(\d+)\];", line)
            ctrl = parse(Int, m.captures[1]) + 1
            target = parse(Int, m.captures[2]) + 1
            Circuit.add_gatecall!(circ, c_z(target, ctrl))

        # Swap gate
        elseif occursin(r"^swap\s+q\[", line)
            m = match(r"swap\s+q\[(\d+)\],\s*q\[(\d+)\];", line)
            qubit1 = parse(Int, m.captures[1]) + 1
            qubit2 = parse(Int, m.captures[2]) + 1
            Circuit.add_gatecall!(circ, swap(qubit1, qubit2))

        # Controlled phase (CP) parametric gate
        elseif occursin(r"^cp\(", line)
            m = match(r"cp\((.*)\)\s+q\[(\d+)\],\s*q\[(\d+)\];", line)
            if m !== nothing
                angle = eval(Meta.parse(m.captures[1]))
                ctrl = parse(Int, m.captures[2]) + 1
                target = parse(Int, m.captures[3]) + 1
                # add_gatecall!(circ, c_phase(ctrl, target, angle))
                circ << c_r_phase(target, ctrl, angle)
            else
                @warn "Invalid format for CP gate: $line"
            end

        else
            println(" Unprocessed element: $line ")
        end
    catch e
        @warn "Could not process the line: $line. Error: $e"
    end
end


# Generic functions in QXZoo to handle u1, u2, p and other Qiskit gates

using QXZoo
using LinearAlgebra

# Define U₂(0,0) ≈ Hadamard (H)
"""
    u2(phi, lambda)

Return the matrix of the Qiskit `U2` single-qubit gate, parametrised by
`phi` and `lambda`.
"""
function u2(phi, lambda)
    return (1/sqrt(2)) * [
        1                    -exp(im * lambda);
        exp(im * phi)         exp(im * (phi + lambda))
    ]
end


# Define U1
"""
    u1(phi)

Return the matrix of the Qiskit `U1` single-qubit phase gate, parametrised
by `phi`.
"""
function u1(phi)
    return [
        1            0   ;
        0          exp(im * (phi))
    ]
end


# Define p, which is the same as u1
"""
    p(phi)

Return the matrix of the Qiskit `P` (phase) gate, which coincides with `U1`.
"""
function p(phi)
    return [
        1            0   ;
        0          exp(im * (phi))
    ]
end


# Two-qubit gates

"""
    phase_gate_2qubits(phi)

Return the 4×4 matrix of the two-qubit controlled-phase gate with phase
`phi`.
"""
function phase_gate_2qubits(phi)
    # 4×4 matrix for two qubits
    [1 0 0 0;
     0 1 0 0;
     0 0 1 0;
     0 0 0 exp(im*phi)]
end


## Adapt QWalk files so that they can be used in QXZoo by renaming the qubits

"""
    replace_qasm_registers_grover(input_file::String, output_file::String="output.qasm")

Adapt QWalk/Grover QASM files so that they can be used in QXZoo by renaming
the `node`, `coin` and `flag` registers into a single `q` register.

# Arguments
- `input_file::String`: path to the input QASM file.
- `output_file::String="output.qasm"`: path to the rewritten QASM file.

# Returns
- `new_content::String`: the rewritten QASM content.
"""
function replace_qasm_registers_grover(input_file::String, output_file::String="output.qasm")
    # Read the file content
    content = read(input_file, String)

    # Build the substitution dictionary
    replacements = Dict{String,String}()

    # Process the register definitions
    node_q = 0
    node_count = 0
    coin_count = 0
    flag_count = 0

    # Locate the register definitions
    for line in split(content, '\n')
        # println(line)
        if occursin(r"qreg\s+node\[(\d+)\];", line)
            node_count = parse(Int, match(r"qreg\s+node\[(\d+)\];", line).captures[1])
            println("node_count: $node_count")
        elseif occursin(r"qreg\sq\[(\d+)\];", line)
            node_q = parse(Int, match(r"qreg\sq\[(\d+)\];", line).captures[1])
            println("node_q: $node_q")
        elseif occursin(r"qreg\s+coin\[(\d+)\];", line)
            coin_count = parse(Int, match(r"qreg\s+coin\[(\d+)\];", line).captures[1])
            println(coin_count)
            println("coin count:$coin_count")
        elseif occursin(r"qreg\s+flag\[(\d+)\];", line)
            flag_count = parse(Int, match(r"qreg\s+flag\[(\d+)\];", line).captures[1])
            println("flag count:$flag_count")
        end
    end

    # Build the substitution for `node`
    for i in 0:(node_count-1)
        replacements["node[$i]"] = "q[$i]"
    end

    # Build the substitution for `coin`
    for i in 0:(coin_count-1)
        replacements["coin[$i]"] = "q[$(i+node_count)]"
    end

    # Build the substitution for `flag`
    for i in 0:(flag_count-1)
        replacements["flag[$i]"] = "q[$(i+node_q)]"
    end

    # Apply the substitutions
    new_content = content
    for (old, new) in replacements
        new_content = replace(new_content, old => new)
    end

    # Replace the register definitions
    if node_q > 0 || node_count > 0 || coin_count > 0 || flag_count > 0
        total_qubits = node_count + coin_count + flag_count + node_q
        # println(total_qubits)
        # new_content = replace(new_content, r"qreg\s+node\[\d+\];\s*qreg\s+coin\[\d+\];" => "qreg q[$total_qubits];")
        new_content = replace(new_content,
                              r"qreg\s+q\[\d+\];\s*qreg\s+flag\[\d+\];" =>
                              "qreg q[$total_qubits];")
        # println(new_content)
    end

    # Write the output file
    write(output_file, new_content)

    return new_content
end


# This function fixes the bug present in the previous version of the function:
# in Qiskit the order is control, target, whereas in QXZoo it is reversed.

"""
    process_gate_line!(circ::QXZoo.Circuit.Circ, line::String)

Parse a single QASM gate line and append the corresponding gate to the
QXZoo circuit. Handles single-qubit gates (x, y, z, h, s, t, sx, rx, ry, rz,
u1, u2, p) and two-qubit gates (cx, cy, cz, cu1, swap, cp).

# Arguments
- `circ::QXZoo.Circuit.Circ`: the target QXZoo circuit.
- `line::String`: a single QASM gate line.

# Notes
- Qiskit QASM indices are 0-based while QXZoo indices are 1-based, so every
  parsed qubit index is incremented by 1.
- The control/target order of two-qubit gates is reversed with respect to
  Qiskit, matching QXZoo's convention.
- Parsing errors are reported with `@warn` and do not abort the loop.
"""
function process_gate_line!(circ::QXZoo.Circuit.Circ, line::String)
    try
        # Remove leading and trailing whitespace
        line = strip(line)

        # Single-qubit, non-parametric gates
        if occursin(r"^x\s+q\[", line)
            qubit = parse(Int, match(r"x\s+q\[(\d+)\];", line).captures[1]) + 1
            Circuit.add_gatecall!(circ, x(qubit))

        elseif occursin(r"^y\s+q\[", line)
            qubit = parse(Int, match(r"y\s+q\[(\d+)\];", line).captures[1]) + 1
            Circuit.add_gatecall!(circ, y(qubit))

        elseif occursin(r"^z\s+q\[", line)
            qubit = parse(Int, match(r"z\s+q\[(\d+)\];", line).captures[1]) + 1
            Circuit.add_gatecall!(circ, z(qubit))

        elseif occursin(r"^h\s+q\[", line)
            qubit = parse(Int, match(r"h\s+q\[(\d+)\];", line).captures[1]) + 1
            Circuit.add_gatecall!(circ, h(qubit))

        elseif occursin(r"^s\s+q\[", line)
            qubit = parse(Int, match(r"s\s+q\[(\d+)\];", line).captures[1]) + 1
            Circuit.add_gatecall!(circ, s(qubit))

        elseif occursin(r"^t\s+q\[", line)
            qubit = parse(Int, match(r"t\s+q\[(\d+)\];", line).captures[1]) + 1
            Circuit.add_gatecall!(circ, t(qubit))

        # Single-qubit parametric gates (no space after the gate name)
        elseif occursin(r"^rx\(", line)
            m = match(r"rx\((.*)\)\s+q\[(\d+)\];", line)
            angle = eval(Meta.parse(m.captures[1]))   # allows expressions like pi/2
            qubit = parse(Int, m.captures[2]) + 1
            Circuit.add_gatecall!(circ, r_x(qubit, angle))

        # New search patterns for u2 and u1
        elseif occursin(r"^u2\(", line)
            pattern = r"u2\(([^,]+),\s*([^)]+)\)\s+q\[(\d+)\]"
            # Look for matches
            m = match(pattern, line)

            if m === nothing
                error("Invalid line format. Expected 'u2(angle1,angle2) q[qubit]'")
            end

            # Extract and convert the values
            angle1_str = m.captures[1]
            angle2_str = m.captures[2]
            qubit_str  = m.captures[3]

            # Parse the angles (may contain mathematical expressions like pi/2)
            angle1 = eval(Meta.parse(angle1_str))
            angle2 = eval(Meta.parse(angle2_str))

            # Convert the qubit to an integer
            qubit = parse(Int, qubit_str) + 1

            # Now build the corresponding gate
            phi = angle1
            lambda = angle2
            matriu = u2(phi, lambda)
            nova_porta_1q_u2 = create_gate_1q("nova_porta_1q_u2", u2(phi, lambda))
            circ << u(nova_porta_1q_u2, qubit)

        # New search patterns for u2 and u1
        elseif occursin(r"^u1\(", line)
            pattern = r"u1\(([^)]+)\)\s+q\[(\d+)\];"

            # Look for matches
            m = match(pattern, line)

            if m === nothing
                error("Invalid line format. Expected 'u1(angle) q[qubit];'")
            end

            # Extract and convert the values
            angle_str = m.captures[1]
            qubit_str = m.captures[2]

            # Parse the angle (may contain mathematical expressions like pi/2)
            angle = eval(Meta.parse(angle_str))

            # Convert the qubit to an integer
            qubit = parse(Int, qubit_str) + 1

            # Now build the corresponding gate
            phi = angle
            # lambda = angle2
            matriu = u1(phi)
            nova_porta_1q_u1 = create_gate_1q("nova_porta_1q_u1", u1(phi))
            circ << u(nova_porta_1q_u1, qubit)

        # New search pattern for the p gate
        elseif occursin(r"^p\(", line)
            pattern = r"p\(([^)]+)\)\s+q\[(\d+)\];"

            # Look for matches
            m = match(pattern, line)

            if m === nothing
                error("Invalid line format. Expected 'p(angle) q[qubit];'")
            end

            # Extract and convert the values
            angle_str = m.captures[1]
            qubit_str = m.captures[2]

            # Parse the angle (may contain mathematical expressions like pi/2)
            angle = eval(Meta.parse(angle_str))

            # Convert the qubit to an integer
            qubit = parse(Int, qubit_str) + 1

            # Now build the corresponding gate
            phi = angle
            # lambda = angle2
            matriu = p(phi)
            nova_porta_1q_p = create_gate_1q("nova_porta_1q_p", p(phi))
            circ << u(nova_porta_1q_p, qubit)

        elseif occursin(r"^sx\s+q\[", line)
            # Process sx (equivalent to rx(pi/2))
            m = match(r"sx\s+q\[(\d+)\];", line)
            angle = pi/2
            qubit = parse(Int, m.captures[1]) + 1
            # println("$angle, angle and qubit $qubit in the sx gate")
            Circuit.add_gatecall!(circ, r_x(qubit, angle))

        elseif occursin(r"^ry\(", line)
            m = match(r"ry\((.*)\)\s+q\[(\d+)\];", line)
            angle = eval(Meta.parse(m.captures[1]))
            qubit = parse(Int, m.captures[2]) + 1
            Circuit.add_gatecall!(circ, r_y(qubit, angle))

        elseif occursin(r"^rz\(", line)
            m = match(r"rz\((.*)\)\s+q\[(\d+)\];", line)
            angle = eval(Meta.parse(m.captures[1]))
            qubit = parse(Int, m.captures[2]) + 1
            Circuit.add_gatecall!(circ, r_z(qubit, angle))

        # Two-qubit, non-parametric gates
        elseif occursin(r"^cx\s+q\[", line)
            m = match(r"cx\s+q\[(\d+)\],\s*q\[(\d+)\];", line)
            ctrl = parse(Int, m.captures[1]) + 1
            target = parse(Int, m.captures[2]) + 1
            Circuit.add_gatecall!(circ, c_x(target, ctrl))

        elseif occursin(r"^cy\s+q\[", line)
            m = match(r"cy\s+q\[(\d+)\],\s*q\[(\d+)\];", line)
            ctrl = parse(Int, m.captures[1]) + 1
            target = parse(Int, m.captures[2]) + 1
            Circuit.add_gatecall!(circ, c_y(target, ctrl))

        elseif occursin(r"^cz\s+q\[", line)
            m = match(r"cz\s+q\[(\d+)\],\s*q\[(\d+)\];", line)
            ctrl = parse(Int, m.captures[1]) + 1
            target = parse(Int, m.captures[2]) + 1
            Circuit.add_gatecall!(circ, c_z(target, ctrl))

        # New cu1 two-qubit gate
        elseif occursin(r"^cu1\(", line)
            # Regex pattern to extract the components
            pattern = r"cu1\(([^)]+)\)\s+q\[(\d+)\],q\[(\d+)\];"

            # Look for matches
            m = match(pattern, line)

            if m === nothing
                error("Invalid line format. Expected 'cu1(angle) q[qubit1],q[qubit2];'")
            end

            # Extract and convert the values
            angle_str  = m.captures[1]
            qubit1_str = m.captures[2]
            qubit2_str = m.c
            
          
                    
