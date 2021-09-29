import string
import random

import numpy as np
import tensorflow as tf
from tensorflow.python.keras.preprocessing.sequence import pad_sequences

from main import x_train, responses, encoder,tokenizer


interpreter = tf.lite.Interpreter(model_path="../app/assets/model.tflite")
interpreter.allocate_tensors()
input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()
input_shape = input_details[0]['shape']

while True:

    texts_p = []
    prediction_input = input('You : ')
    # removing punctuation and converting to lowercase
    prediction_input = [letters.lower() for letters in prediction_input if letters not in string.punctuation]
    prediction_input = ''.join(prediction_input)
    texts_p.append(prediction_input)
    # tokenizing and padding
    prediction_input = tokenizer.texts_to_sequences(texts_p)
    print(prediction_input)
    prediction_input = np.array(prediction_input, dtype=np.float32).reshape(-1)
    print(prediction_input)
    prediction_input = pad_sequences([prediction_input], input_shape[1])
    prediction_input = np.array(prediction_input, dtype=np.float32)
    print(prediction_input.tolist())
    # getting output from model
    # getting output from model
    interpreter.set_tensor(input_details[0]['index'], prediction_input)
    interpreter.invoke()
    tflite_results = interpreter.get_tensor(output_details[0]['index'])
    print(tflite_results)
    output = tflite_results.argmax()
    # finding the right tag and predicting
    response_tag = encoder.inverse_transform([output])[0]
    print()
    print("bot : ", random.choice(responses[response_tag]))
    if response_tag == "goodbye":
        break
