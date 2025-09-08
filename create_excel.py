#!/usr/bin/env python3
import csv
import json
from datetime import datetime

# Read the CSV data
data = []
with open('/app/neurohydration_twitter_calendar_2025.csv', 'r', newline='', encoding='utf-8') as csvfile:
    reader = csv.DictReader(csvfile)
    for row in reader:
        # Parse date and add enhanced fields
        date_obj = datetime.strptime(row['Date'], '%Y-%m-%d')
        
        enhanced_row = {
            'Date': row['Date'],
            'Day_of_Week': row['Day'],
            'Month': date_obj.strftime('%B'),
            'Week_Number': date_obj.isocalendar()[1],
            'Content_Type': row['Content Type'],
            'Post_Content': row['Post'],
            'Hashtags': row['Hashtags'],
            'Character_Count': len(row['Post']),
            'Twitter_Safe': 'Yes' if len(row['Post']) <= 280 else 'No',
            'Month_Number': date_obj.month
        }
        data.append(enhanced_row)

# Create HTML file that can be opened in Excel
html_content = '''<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Neurohydration Twitter Calendar 2025</title>
    <style>
        table { border-collapse: collapse; width: 100%; font-family: Arial; }
        th { background-color: #366092; color: white; font-weight: bold; padding: 8px; border: 1px solid #ddd; }
        td { padding: 6px; border: 1px solid #ddd; vertical-align: top; }
        tr:nth-child(even) { background-color: #f2f2f2; }
        .post-content { max-width: 400px; word-wrap: break-word; }
        .char-count { text-align: center; }
        .safe-yes { color: green; font-weight: bold; }
        .safe-no { color: red; font-weight: bold; }
    </style>
</head>
<body>
    <h1>Neurohydration Twitter Calendar 2025</h1>
    <p>365 Days of Deep Ingredient Education for Dysautonomia</p>
    
    <table>
        <thead>
            <tr>
                <th>Date</th>
                <th>Day</th>
                <th>Month</th>
                <th>Week #</th>
                <th>Content Type</th>
                <th>Post Content</th>
                <th>Hashtags</th>
                <th>Character Count</th>
                <th>Twitter Safe</th>
            </tr>
        </thead>
        <tbody>
'''

for row in data:
    safe_class = 'safe-yes' if row['Twitter_Safe'] == 'Yes' else 'safe-no'
    html_content += f'''
            <tr>
                <td>{row['Date']}</td>
                <td>{row['Day_of_Week']}</td>
                <td>{row['Month']}</td>
                <td>{row['Week_Number']}</td>
                <td>{row['Content_Type']}</td>
                <td class="post-content">{row['Post_Content']}</td>
                <td>{row['Hashtags']}</td>
                <td class="char-count">{row['Character_Count']}</td>
                <td class="{safe_class}">{row['Twitter_Safe']}</td>
            </tr>'''

html_content += '''
        </tbody>
    </table>
</body>
</html>'''

# Save HTML file
with open('/app/neurohydration_twitter_calendar_2025.html', 'w', encoding='utf-8') as f:
    f.write(html_content)

# Also create a tab-separated file that Excel prefers
with open('/app/neurohydration_twitter_calendar_2025.tsv', 'w', newline='', encoding='utf-8') as tsvfile:
    fieldnames = ['Date', 'Day_of_Week', 'Month', 'Week_Number', 'Content_Type', 'Post_Content', 'Hashtags', 'Character_Count', 'Twitter_Safe']
    writer = csv.DictWriter(tsvfile, fieldnames=fieldnames, delimiter='\t')
    
    writer.writeheader()
    for row in data:
        writer.writerow({
            'Date': row['Date'],
            'Day_of_Week': row['Day_of_Week'],
            'Month': row['Month'],
            'Week_Number': row['Week_Number'],
            'Content_Type': row['Content_Type'],
            'Post_Content': row['Post_Content'],
            'Hashtags': row['Hashtags'],
            'Character_Count': row['Character_Count'],
            'Twitter_Safe': row['Twitter_Safe']
        })

print("Created multiple Excel-friendly formats:")
print("- Enhanced CSV: neurohydration_twitter_calendar_2025_excel.csv")
print("- HTML table: neurohydration_twitter_calendar_2025.html")  
print("- TSV file: neurohydration_twitter_calendar_2025.tsv")
print(f"Total posts: {len(data)}")
print("All files can be opened directly in Excel!")