import os
import random
import numpy as np
import subprocess
import shutil
import sys
import argparse

def read_config(config_file="config.txt"):
    config = {
        "regenerate_input": False,
        "cpp_file": "convolution.cpp",
        "exe_name": "convolution",
        "num_tests": 100,
        "mars_jar": "Mars4_5.jar",
        "asm_file": "convolution.asm",
        "epsilon": 1e-4
    }
    
    if os.path.exists(config_file):
        with open(config_file, "r") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                    
                if '=' not in line:
                    continue
                    
                key, value = [x.strip() for x in line.split('=', 1)]
                value = value.split('#')[0].strip()
                
                if value.lower() == "true":
                    value = True
                elif value.lower() == "false":
                    value = False
                elif value.isdigit():
                    value = int(value)
                elif value.replace('.','',1).isdigit():
                    value = float(value)
                    
                config[key] = value
    return config

def compare_outputs(expected_file, output_file, epsilon):
    try:
        with open(expected_file, 'r') as f:
            expected_content = f.read().strip()
            if not any(c.isdigit() for c in expected_content):
                with open(output_file, 'r') as f2:
                    output_content = f2.read().strip()
                    return expected_content.lower() == output_content.lower()
            
            expected = [float(x) for x in expected_content.split()]
    except (ValueError, FileNotFoundError) as e:
        print(f"\nError reading expected file {expected_file}: {e}")
        return False

    try:
        with open(output_file, 'r') as f:
            output_content = f.read().strip()
            if not any(c.isdigit() for c in output_content):
                return False
            
            output = [float(x) for x in output_content.split()]
    except (ValueError, FileNotFoundError) as e:
        print(f"\nError reading output file {output_file}: {e}")
        return False

    if len(expected) != len(output):
        print(f"\nLength mismatch: expected {len(expected)}, got {len(output)}")
        return False

    for i, (e, o) in enumerate(zip(expected, output)):
        if abs(e - o) > epsilon:
            print(f"\nMismatch at position {i}: expected {e}, got {o}, diff {abs(e - o)}")
            return False
    
    return True

class ConvolutionTestGenerator:
    def __init__(self):
        self.config = read_config()
        self.cpp_file = self.config["cpp_file"]
        self.exe_name = self.config["exe_name"]
        self.regenerate_input = self.config["regenerate_input"]
        self.total_passed = 0
        self.failed_cases = []
            
    def generate_random_params(self):
        N = random.randint(3, 7)
        M = random.randint(2, 4)
        p = random.randint(0, 4)
        s = random.randint(1, 3)
        if ((N + 2*p - M) // s + 1) < 1:
            return self.generate_random_params()
        return N, M, p, s
            
    def ensure_directory(self, path):
        if not os.path.exists(path):
            os.makedirs(path)
                
    def generate_test_case(self, index, verbose=False):
        input_dir = os.path.join(os.getcwd(), "input_matrices")
        expected_dir = os.path.join(os.getcwd(), "expected_matrices")
        output_dir = os.path.join(os.getcwd(), "output_matrices")
        
        self.ensure_directory(input_dir)
        self.ensure_directory(expected_dir)
        self.ensure_directory(output_dir)
        
        input_path = os.path.join(input_dir, f"input_matrix_{index}.txt")
        should_generate = self.regenerate_input or not os.path.exists(input_path)
        
        if should_generate:
            N, M, p, s = self.generate_random_params()
            img = np.random.random((N, N))
            kernel = np.random.random((M, M))
            
            with open(input_path, "w") as f:
                f.write(f"{N} {M} {p} {s}\n")
                f.write(" ".join(f"{x:.6f}" for x in img.flatten()) + "\n")
                f.write(" ".join(f"{x:.6f}" for x in kernel.flatten()))
                
            if verbose:
                print(f"\nGenerated test case {index} with parameters:")
                print(f"N={N}, M={M}, p={p}, s={s}")
        elif verbose:
            with open(input_path, 'r') as f:
                first_line = f.readline().strip()
                N, M, p, s = map(int, first_line.split())
                print(f"\nTest case {index} parameters:")
                print(f"N={N}, M={M}, p={p}, s={s}")
        
        shutil.copy(input_path, "input_matrix.txt")
        subprocess.run(["g++", self.cpp_file, "-o", self.exe_name], capture_output=True)
        subprocess.run([f"./{self.exe_name}"], capture_output=True)
        
        if os.path.exists("output_matrix.txt"):
            expected_path = os.path.join(expected_dir, f"expected_matrix_{index}.txt")
            if os.path.exists(expected_path):
                os.remove(expected_path)
            os.rename("output_matrix.txt", expected_path)
            
            subprocess.run(["java", "-jar", self.config["mars_jar"], self.config["asm_file"]], capture_output=True)
            
            output_path = os.path.join(output_dir, f"output_matrix_{index}.txt")
            if os.path.exists("output_matrix.txt"):
                if os.path.exists(output_path):
                    os.remove(output_path)
                os.rename("output_matrix.txt", output_path)
                
                if not verbose:
                    print(index, end=' ')
                    sys.stdout.flush()
                
                result = compare_outputs(expected_path, output_path, self.config["epsilon"])
                if not result:
                    self.failed_cases.append(index)
                    if verbose:
                        print("\nTest case failed")
                        print("Input content:")
                        with open(input_path, 'r') as f:
                            print(f.read())
                        print("\nExpected output:")
                        with open(expected_path, 'r') as f:
                            print(f.read())
                        print("\nActual output:")
                        with open(output_path, 'r') as f:
                            print(f.read())
                return result
        self.failed_cases.append(index)    
        return False

    def run_single_test(self, test_num):
        """Run a specific test case with verbose output"""
        if test_num < 1 or test_num > self.config["num_tests"]:
            print(f"Error: test case must be between 1 and {self.config['num_tests']}")
            return False
            
        print(f"Running...")
        result = self.generate_test_case(test_num)
        
        if result:
            print(f"\nTest case PASSED ✓")
        else:
            print(f"\nTest case FAILED ✗")
        
        return result
    

    def run_all_tests(self):
        """Run all test cases"""
        print("Running...")
        for i in range(1, self.config["num_tests"] + 1):
            if self.generate_test_case(i):
                self.total_passed += 1
        
        print(f"\n\nResults: {self.total_passed}/{self.config['num_tests']} tests PASSED ✓"
              f"({self.total_passed/self.config['num_tests']*100:.1f}%)")
        if self.failed_cases:
            print(f"Failed test cases: {', '.join(map(str, self.failed_cases))} ✗")

def main():
    parser = argparse.ArgumentParser(description='Run convolution test cases')
    parser.add_argument('-t', '--test', type=int, help='Specific test case number to run')
    args = parser.parse_args()

    generator = ConvolutionTestGenerator()
    
    if args.test is not None:
        generator.run_single_test(args.test)
    else:
        generator.run_all_tests()

if __name__ == "__main__":
    main()