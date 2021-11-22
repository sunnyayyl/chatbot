import json
import os
import string
import pandas as pd
import tensorflow as tf
import tensorflow.keras as keras
from keras import Input
from keras import layers
from numpyencoder import NumpyEncoder
from sklearn.preprocessing import LabelEncoder
tags = []
response = []
inputs = []
responses = {}
encoder = LabelEncoder()
tokenizer = keras.preprocessing.text.Tokenizer(num_words=2000)

with open("data.json") as f:
    data = json.load(f)
for i in data:
    responses[i['tag']] = i['responses']
    for ii in i["input"]:
        inputs.append(ii)
        tags.append(i["tag"])
data = pd.DataFrame({"tags": tags, "inputs": inputs})
data['inputs'] = [a.translate(str.maketrans("", "", string.punctuation)).lower() for a in data['inputs']]
data['inputs'] = data['inputs'].apply(lambda wrd: ''.join(wrd))
print(data)
tokenizer.fit_on_texts(data['inputs'])
train = tokenizer.texts_to_sequences(data['inputs'])
x_train = keras.preprocessing.sequence.pad_sequences(train)
y_train = encoder.fit_transform(data['tags'])
input_shape = x_train.shape[1]
word_count = len(tokenizer.word_index)
output_length = encoder.classes_.shape[0]
model = keras.Sequential()
model.add(Input(shape=(input_shape,)))
model.add(layers.Embedding(word_count + 1, 10))
model.add(layers.LSTM(10, return_sequences=True))
model.add(layers.Flatten())
model.add(layers.Dense(output_length, activation="softmax"))
model.compile(loss="sparse_categorical_crossentropy", optimizer='adam', metrics=['accuracy'])
train = model.fit(x_train, y_train, epochs=200)

converter = tf.lite.TFLiteConverter.from_keras_model(model)
tflite_model = converter.convert()
with open('../app/assets/model.tflite', 'wb') as f:
    f.write(tflite_model)
with open('../app/assets/word_dict.json', 'w') as f:
    json.dump(tokenizer.word_index, f)
with open('../app/assets/encoder.json', 'w') as f:
    json.dump(dict(zip(encoder.classes_, encoder.transform(encoder.classes_))), f, cls=NumpyEncoder)
with open('../app/assets/responses.json', 'w') as f:
    with open("data.json") as ff:
        data = json.load(ff)
    out = {}
    for iii in data:
        out[iii["tag"]] = iii["responses"]
    json.dump(out, f)
with open('../app/assets/jobs.json', 'w') as f:
    with open("data.json") as ff:
        data = json.load(ff)
    out = {}
    for iii in data:
        if "jobs" in iii:
            out[iii["tag"]] = iii["jobs"]
    json.dump(out, f)


