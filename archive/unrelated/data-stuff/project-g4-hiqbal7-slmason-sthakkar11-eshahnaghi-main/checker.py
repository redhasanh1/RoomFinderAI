import csv
import os
from collections import Counter

def check_athletes_file():
    """Check new_olympic_athlete_bio.csv for issues"""
    print("\n" + "="*60)
    print("CHECKING: new_olympic_athlete_bio.csv")
    print("="*60)

    issues = []

    with open('new_olympic_athlete_bio.csv', 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        header = next(reader)

        print(f"Header: {header}")
        # Bio file has more columns - just print header for now
        print(f"Number of columns: {len(header)}")

        rows = list(reader)
        print(f"Total athletes: {len(rows)}")

        # Check for common issues
        empty_fields = Counter()
        sex_values = Counter()
        noc_lengths = Counter()
        date_formats = Counter()
        name_issues = []

        for i, row in enumerate(rows):
            if len(row) != 7:
                issues.append(f"Row {i+2}: Wrong number of fields ({len(row)} instead of 7)")
                continue

            name, sex, born, height, weight, country, noc = row

            # Check empty fields
            for j, (field, value) in enumerate(zip(header, row)):
                if not value.strip():
                    empty_fields[field] += 1

            # Check sex values
            sex_values[sex] += 1

            # Check NOC length
            noc_lengths[len(noc)] += 1

            # Check date format
            if born:
                if '-' in born:
                    parts = born.split('-')
                    if len(parts) == 3 and len(parts[0]) == 4:
                        date_formats['YYYY-MM-DD'] += 1
                    else:
                        date_formats['other-dash'] += 1
                elif '/' in born:
                    date_formats['slash'] += 1
                else:
                    date_formats['unknown'] += 1

            # Check name format
            if ',' in name:
                name_issues.append(f"Row {i+2}: Name has comma: {name}")

        # Print findings
        print(f"\nSex values: {dict(sex_values)}")
        if 'Male' in sex_values or 'Female' in sex_values:
            issues.append("Sex should be 'M'/'F', not 'Male'/'Female'")

        print(f"NOC lengths: {dict(noc_lengths)}")
        if 2 in noc_lengths or any(l > 3 for l in noc_lengths.keys()):
            issues.append("Some NOC codes are not 3 characters")

        print(f"Date formats: {dict(date_formats)}")
        if 'slash' in date_formats or 'other-dash' in date_formats:
            issues.append("Some dates not in YYYY-MM-DD format")

        print(f"Empty fields: {dict(empty_fields)}")

        if name_issues:
            print(f"\nName issues (first 5): {name_issues[:5]}")
            issues.append(f"{len(name_issues)} names contain commas")

        # Sample rows
        print("\nSample rows:")
        for row in rows[:3]:
            print(f"  {row}")

    return issues

def check_events_file():
    """Check new_olympic_athlete_event_results.csv for issues"""
    print("\n" + "="*60)
    print("CHECKING: new_olympic_athlete_event_results.csv")
    print("="*60)

    issues = []

    with open('new_olympic_athlete_event_results.csv', 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        header = next(reader)

        print(f"Header: {header}")
        expected_header = ['edition', 'edition_id', 'country_noc', 'sport', 'event',
                         'result_id', 'athlete', 'athlete_id', 'pos', 'medal', 'isTeamSport', 'age']
        if header != expected_header:
            issues.append(f"Header mismatch! Expected: {expected_header}")

        rows = list(reader)
        print(f"Total results: {len(rows)}")

        # Check for common issues
        editions = Counter()
        medals = Counter()
        team_sport_values = Counter()
        noc_lengths = Counter()
        event_quotes = 0
        age_issues = []

        for i, row in enumerate(rows):
            if len(row) != 12:
                issues.append(f"Row {i+2}: Wrong number of fields ({len(row)} instead of 12)")
                continue

            edition, edition_id, noc, sport, event, result_id, athlete, athlete_id, pos, medal, is_team, age = row

            editions[edition] += 1
            medals[medal] += 1
            team_sport_values[is_team] += 1
            noc_lengths[len(noc)] += 1

            # Check for quoted events
            if event.startswith('"') or event.endswith('"'):
                event_quotes += 1

            # Check age
            if age:
                try:
                    age_val = int(age)
                    if age_val < 10 or age_val > 80:
                        age_issues.append(f"Row {i+2}: Unusual age {age}")
                except:
                    age_issues.append(f"Row {i+2}: Invalid age format: {age}")

        # Print findings
        print(f"\nEditions: {dict(editions)}")

        print(f"\nMedals: {dict(medals)}")
        if 'Gold' in medals or 'Silver' in medals or 'Bronze' in medals:
            issues.append("Medals should be 'gold'/'silver'/'bronze' (lowercase)")
        if '' not in medals and 'NA' not in medals:
            print("  Note: No empty/NA medals found - this might be wrong if there are non-medalists")

        print(f"\nisTeamSport values: {dict(team_sport_values)}")
        expected_team = {'True', 'False'}
        if not set(team_sport_values.keys()).issubset(expected_team):
            issues.append(f"isTeamSport should be 'True'/'False', got: {set(team_sport_values.keys())}")

        print(f"\nNOC lengths: {dict(noc_lengths)}")

        if event_quotes > 0:
            issues.append(f"{event_quotes} events have quotes")

        if age_issues:
            print(f"\nAge issues (first 5): {age_issues[:5]}")

        # Check Paris 2024 specifically
        paris_rows = [r for r in rows if '2024' in r[0]]
        print(f"\nParis 2024 results: {len(paris_rows)}")

        if paris_rows:
            # Sample Paris rows
            print("\nSample Paris 2024 rows:")
            for row in paris_rows[:3]:
                print(f"  {row}")

            # Check Paris medals
            paris_medals = Counter(r[9] for r in paris_rows)
            print(f"\nParis medals: {dict(paris_medals)}")

            # Check Paris isTeamSport
            paris_team = Counter(r[10] for r in paris_rows)
            print(f"Paris isTeamSport: {dict(paris_team)}")

    return issues

def check_cross_references():
    """Check that athletes in events exist in athletes file"""
    print("\n" + "="*60)
    print("CROSS-REFERENCE CHECK")
    print("="*60)

    issues = []

    # Load athletes
    athletes = set()
    with open('new_olympic_athlete_bio.csv', 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        next(reader)  # skip header
        for row in reader:
            if len(row) >= 1:
                athletes.add(row[0])

    # Check events
    missing_athletes = Counter()
    with open('new_olympic_athlete_event_results.csv', 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        next(reader)  # skip header
        for row in reader:
            if len(row) >= 7:
                athlete = row[6]
                if athlete not in athletes:
                    missing_athletes[athlete] += 1

    if missing_athletes:
        print(f"\nAthletes in events but not in athletes file: {len(missing_athletes)}")
        most_common = missing_athletes.most_common(10)
        print(f"Most common missing: {most_common}")
        issues.append(f"{len(missing_athletes)} athletes in events not found in athletes file")
    else:
        print("\n✓ All athletes in events exist in athletes file")

    return issues

def main():
    os.chdir(os.path.dirname(os.path.abspath(__file__)))

    all_issues = []

    all_issues.extend(check_athletes_file())
    all_issues.extend(check_events_file())
    all_issues.extend(check_cross_references())

    print("\n" + "="*60)
    print("SUMMARY OF ISSUES")
    print("="*60)

    if all_issues:
        for i, issue in enumerate(all_issues, 1):
            print(f"{i}. {issue}")
    else:
        print("No issues found!")

    print("\n")

if __name__ == '__main__':
    main()
