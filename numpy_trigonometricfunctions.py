# -*- coding: utf-8 -*-
"""Numpy_TrigonometricFunctions.ipynb

Automatically generated by Colab.

Original file is located at
    https://colab.research.google.com/drive/1GY4IKny781zHa3Py4X80c0GkJmpan9pU
"""

# Example 5: NumPy - Trigonometric Functions
import numpy as np

# Creating an array
angles = np.array([0, np.pi/2, np.pi])

# Trigonometric functions
sin_array = np.sin(angles)
cos_array = np.cos(angles)
tan_array = np.tan(angles)

print('Sine of Angles:', sin_array)
print('Cosine of Angles:', cos_array)
print('Tangent of Angles:', tan_array)