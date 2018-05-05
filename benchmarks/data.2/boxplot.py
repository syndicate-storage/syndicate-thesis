#!/usr/bin/env python2

import matplotlib as mpl
# force truetype
mpl.rcParams['pdf.fonttype'] = 42
mpl.rcParams['ps.fonttype'] = 42

import csv
import sys
import os
import re

## agg backend is used to create plot as a .png file
# mpl.use('agg')

import matplotlib.pyplot as plt 

column_name = sys.argv[1]
row_paths = sys.argv[2:]

xlabel = 'File Size'
ylabel = 'Time (seconds)'
save = False

if os.environ.get('Y_AXIS'):
    ylabel = os.environ['Y_AXIS']

ymin = None
ymax = None
if os.environ.get('Y_MIN'):
    ymin = float(os.environ['Y_MIN'])
if os.environ.get('Y_MAX'):
    ymax = float(os.environ['Y_MAX'])

if os.environ.get('SAVE'):
    save = True

def load_csv(path):
    rows = []
    with open(path, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            rd = {}
            rd.update(row)
            for k in rd:
                rd[k] = float(rd[k])

            rows.append(rd)

    return rows


all_data = []
data_row_labels = []

for path in row_paths:
    csv_data = load_csv(path)
    col_data = [c[column_name] for c in csv_data]

    all_data.append(col_data)
    row_label = os.path.basename(path).split('.')[0].replace('_', ' ')

    if os.environ.get('KILOBYTE_ROWS') and re.match('^[0-9]+$', row_label):
        row_label = str(int(round(int(row_label) / 1024.0))) + 'Kb'

    data_row_labels.append(row_label)

fig = plt.figure(1)
ax = fig.add_subplot(111)
ax.set_xlabel(xlabel)
ax.set_ylabel(ylabel)
for tick in ax.get_xticklabels():
    tick.set_rotation(45)

# ax.set_ylim(0, max(max(dataset) for dataset in all_data) * 1.1)

if ymin is not None and ymax is not None:
    ax.set_ylim(ymin, ymax)

bp = ax.boxplot(all_data, labels=data_row_labels, showfliers=False)

plt.gcf().subplots_adjust(bottom=0.2)

if save:
    plt.savefig(column_name + '.pdf')

else:
    plt.show()
