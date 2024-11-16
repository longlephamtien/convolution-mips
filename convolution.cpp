#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <cstring>

void printMatrix(float** matrix, int rows, int cols, const char* name) {
    printf("\n%s (%dx%d):\n", name, rows, cols);
    for (int i = 0; i < rows; i++) {
        for (int j = 0; j < cols; j++) {
            printf("%f ", matrix[i][j]);
        }
        printf("\n");
    }
}

float** createMatrix(int rows, int cols) {
    float** matrix = (float**)malloc(rows * sizeof(float*));
    for (int i = 0; i < rows; i++) {
        matrix[i] = (float*)malloc(cols * sizeof(float));
    }
    return matrix;
}

void freeMatrix(float** matrix, int rows) {
    for (int i = 0; i < rows; i++) {
        free(matrix[i]);
    }
    free(matrix);
}

float** applyPadding(float** matrix, int size, int padding) {
    int newSize = size + 2 * padding;
    float** paddedMatrix = createMatrix(newSize, newSize);
    
    for (int i = 0; i < newSize; i++) {
        for (int j = 0; j < newSize; j++) {
            paddedMatrix[i][j] = 0.0f;
        }
    }
    
    for (int i = 0; i < size; i++) {
        for (int j = 0; j < size; j++) {
            paddedMatrix[i + padding][j + padding] = matrix[i][j];
        }
    }
    
    return paddedMatrix;
}

float** convolutionPerformance(float** image, int imageSize, float** kernel, int kernelSize, int stride) {
    int outputSize = (imageSize - kernelSize) / stride + 1;
    float** output = createMatrix(outputSize, outputSize);
    
    for (int i = 0; i < outputSize; i++) {
        for (int j = 0; j < outputSize; j++) {
            float sum = 0.0f;
            for (int ki = 0; ki < kernelSize; ki++) {
                for (int kj = 0; kj < kernelSize; kj++) {
                    sum += image[i * stride + ki][j * stride + kj] * kernel[ki][kj];
                }
            }
            output[i][j] = sum;
        }
    }
    
    return output;
}

void writeError(const char* message) {
    FILE* outFile = fopen("output_matrix.txt", "w");
    if (outFile) {
        fprintf(outFile, "%s", message);
        fclose(outFile);
    }
}

// Helper function to format a float with exactly 4 decimal places (truncated, not rounded)
void formatFloat(float value, char* buffer) {
    // Handle the sign first
    if (value < 0) {
        value = -value;
        *buffer++ = '-';
    }
    
    // Get the integer part
    int intPart = (int)value;
    value -= intPart;
    
    // Convert integer part to string
    int intLen = sprintf(buffer, "%d", intPart);
    buffer += intLen;
    
    // Add decimal point
    *buffer++ = '.';
    
    // Handle the decimal part (multiply by 10000 to get 4 decimal places)
    value *= 10000;
    int decimalPart = (int)value; // This truncates to 4 decimal places
    
    // Ensure exactly 4 digits after decimal point
    sprintf(buffer, "%04d", decimalPart);
}

int main() {
    FILE *inFile, *outFile;
    float **image = NULL, **kernel = NULL, **paddedImage = NULL, **result = NULL;
    int N, M, p, s;
    
    inFile = fopen("input_matrix.txt", "r");
    if (!inFile) {
        writeError("Error opening input file");
        return 1;
    }
    
    if (fscanf(inFile, "%d %d %d %d", &N, &M, &p, &s) != 4) {
        writeError("Error reading parameters from input file");
        fclose(inFile);
        return 1;
    }
    
    if (N < 3 || N > 7 || M < 2 || M > 4 || p < 0 || p > 4 || s < 1 || s > 3) {
        writeError("Invalid parameters");
        fclose(inFile);
        return 1;
    }
    
    image = createMatrix(N, N);
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            if (fscanf(inFile, "%f", &image[i][j]) != 1) {
                writeError("Error reading image matrix");
                freeMatrix(image, N);
                fclose(inFile);
                return 1;
            }
        }
    }
    
    kernel = createMatrix(M, M);
    for (int i = 0; i < M; i++) {
        for (int j = 0; j < M; j++) {
            if (fscanf(inFile, "%f", &kernel[i][j]) != 1) {
                writeError("Error reading kernel matrix");
                freeMatrix(image, N);
                freeMatrix(kernel, M);
                fclose(inFile);
                return 1;
            }
        }
    }
    
    fclose(inFile);
    
    paddedImage = image;
    int paddedSize = N;
    if (p > 0) {
        paddedImage = applyPadding(image, N, p);
        paddedSize = N + 2 * p;
        freeMatrix(image, N);
    }
    
    if (paddedSize < M) {
        writeError("Convolution not possible: image too small");
        freeMatrix(paddedImage, paddedSize);
        freeMatrix(kernel, M);
        return 1;
    }
    
    int outputSize = (paddedSize - M) / s + 1;
    if (outputSize <= 0) {
        writeError("Convolution not possible: stride too large");
        freeMatrix(paddedImage, paddedSize);
        freeMatrix(kernel, M);
        return 1;
    }
    
    result = convolutionPerformance(paddedImage, paddedSize, kernel, M, s);
    
    outFile = fopen("output_matrix.txt", "w");
    if (!outFile) {
        writeError("Error opening output file");
        freeMatrix(paddedImage, paddedSize);
        freeMatrix(kernel, M);
        freeMatrix(result, outputSize);
        return 1;
    }
    
    // Buffer for formatted numbers
    char numBuffer[32];
    
    // Write output with exactly 4 decimal places (truncated)
    for (int i = 0; i < outputSize; i++) {
        for (int j = 0; j < outputSize; j++) {
            formatFloat(result[i][j], numBuffer);
            fprintf(outFile, "%s", numBuffer);
            if (!(i == outputSize-1 && j == outputSize-1)) {
                fprintf(outFile, " ");
            }
        }
    }
    
    fclose(outFile);
    freeMatrix(paddedImage, paddedSize);
    freeMatrix(kernel, M);
    freeMatrix(result, outputSize);
    
    return 0;
}