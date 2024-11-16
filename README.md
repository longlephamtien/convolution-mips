# MIPS Matrix Convolution Implementation

This project implements matrix convolution operations in MIPS assembly language, providing a low-level implementation for performing convolution operations on matrices with configurable padding and stride values.

## Overview

The implementation includes:
- Matrix convolution in MIPS assembly
- Input/output handling through text files
- Support for floating-point operations
- Configurable padding and stride
- Automated testing framework in Python

## Requirements

- MARS simulator for MIPS assembly execution
- Python 3.x for running test cases
- C++ compiler (g++) for reference implementation

## Project Structure

```
.
├── README.md
├── convolution.asm        # MIPS implementation
├── convolution.cpp        # C++ reference implementation
├── config.txt             # Test configuration
├── input_matrices/        # Test input files
├── expected_matrices/     # Expected outputs
└── output_matrices/       # MIPS outputs
```

## Implementation Details

### Input Parameters
- N: Image matrix size (3 ≤ N ≤ 7)
- M: Kernel matrix size (2 ≤ M ≤ 4)
- p: Padding size (0 ≤ p ≤ 4)
- s: Stride value (1 ≤ s ≤ 3)

### Key Features
1. Dynamic memory allocation for matrices
2. Zero padding implementation
3. Floating-point arithmetic handling
4. Error checking for invalid parameters
5. File I/O operations

## Testing Program

The Python testing framework provides:
- Automated test case generation
- Comparison with C++ reference implementation
- Configurable test parameters
- Detailed error reporting

### Running Tests

```bash
# Run all test cases
python test_runner.py

# Run a specific test case
python test_runner.py -t <test_number>
```

### Configuration
Test parameters can be modified in `config.txt`:
```
regenerate_input = false
cpp_file = convolution.cpp
exe_name = convolution
num_tests = 100
mars_jar = Mars4_5.jar
asm_file = convolution.asm
epsilon = 0.0001
```

## Input Format

Input files follow this format:
```
N M p s
[N×N matrix elements]
[M×M kernel elements]
```

Example:
```
7 2 4 1
0.072512 0.684725 ... [7×7 matrix]
0.837458 0.065795 ... [2×2 kernel]
```

## Output Format

Output is generated in the format:
```
[result matrix elements with 4 decimal places]
```

## Error Handling

The implementation handles several error cases:
1. Invalid parameters
2. Matrix size mismatches
3. Invalid stride values
4. File I/O errors

Error messages are written to the output file:
- "Invalid parameters"
- "Convolution not possible: image too small"
- "Convolution not possible: stride too large"

## Performance Considerations

The implementation handles:
- Memory efficiency in matrix operations
- Precise floating-point calculations
- Proper initialization of padded matrices
- Efficient convolution computations