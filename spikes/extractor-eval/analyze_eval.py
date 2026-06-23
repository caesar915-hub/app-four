import json
import pandas as pd
from sklearn.metrics import confusion_matrix
import seaborn as sns
import matplotlib.pyplot as plt
import os

def load_data(filepath):
    with open(filepath, 'r') as f:
        return json.load(f)

def analyze_category(category_name, cases):
    df = pd.DataFrame(cases)
    df.fillna({'expected': 'None', 'actual': 'None'}, inplace=True)
    df['expected'] = df['expected'].astype(str)
    df['actual'] = df['actual'].astype(str)

    # Error analysis
    errors = df[df['expected'] != df['actual']]
    
    print(f"\n{'='*50}")
    print(f"CATEGORY: {category_name.upper()}")
    print(f"Total cases: {len(df)}")
    print(f"Errors: {len(errors)} ({len(errors)/len(df)*100:.1f}%)")
    print(f"{'='*50}\n")
    
    if not errors.empty:
        print("--- ERRORS ---")
        for _, row in errors.iterrows():
            print(f"ID: {row['id']}")
            print(f"Transcript: {row['transcript']}")
            print(f"Expected: {row['expected']}  |  Actual: {row['actual']}\n")
            
    # Confusion matrix for ordinal signals
    if category_name in ['mood', 'energy', 'focus']:
        labels = sorted(list(set(df['expected'].unique()) | set(df['actual'].unique())))
        cm = confusion_matrix(df['expected'], df['actual'], labels=labels)
        
        plt.figure(figsize=(8, 6))
        sns.heatmap(cm, annot=True, fmt='d', cmap='Blues', xticklabels=labels, yticklabels=labels)
        plt.title(f'Confusion Matrix: {category_name}')
        plt.xlabel('Predicted')
        plt.ylabel('Actual')
        plt.tight_layout()
        
        out_file = f'spikes/extractor-eval/cm_{category_name}.png'
        plt.savefig(out_file)
        print(f"Saved confusion matrix to {out_file}")

if __name__ == "__main__":
    data = load_data('spikes/extractor-eval/eval_dump.json')
    
    for category, cases in data.items():
        analyze_category(category, cases)
