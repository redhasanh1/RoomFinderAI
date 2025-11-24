# Feel free to add additional python files to this project and import
# them in this file. However, do not change the name of this file
# Avoid the names ms1check.py and ms2check.py as those file names
# are reserved for the autograder

# To run your project use:
#     python runproject.py

# This will ensure that your project runs the way it will run in the
# the test environment


# supports the use of csv library
import csv
# supports the use of regular expressions
import re


def look_for_duplicate_data(row):
    pass

def filter_records(row):
    pass

def sort_by_country_name(file_name, row):
    pass

#this is for adding header: Helps with stuff like for new_olympic_athlete_event_results.csv
def add_header(file_name,newHeader):
    #this will add the new header to the last line
    #for every line we add , to indicate the value is nothing
    
    #it would be something like this
    with open (file_name, "r") as file:
        temp=file.readlines()
        temp[0]+= ("," + newHeader)
    with open (file_name, "w") as file:
        file.write(temp)
    # return file_name
    pass

#completly redo the header
def header_remaster(file_name,new_header_order):
    #we will do basically add header but instead of += we just do = 
    with open (file_name, "r") as file:
        temp=file.readlines()
        temp[0]= new_header_order
    with open (file_name, "w") as file:
        file.write(temp)
    # return file_name
    pass

# Create a new data set, with the column header
def create_data_set(header):

    # Create an empty data set
    data_set = []
    # Append the header to the data set
    data_set.append(header)

    # Return the data set
    return data_set

# ========== TASK 2 - STEPHAN: CLEAN ATHLETE BIO DATA ==========

# Clean athelete bio data
def clean_athlete_bio_data(data_set):
    
    # Correct format for the born column:
    # dd-Mon-yyyy => ^(\d{2})-([A-Z]{1}[a-z]{2})-(\d{4})$
    # Store the regular expression of the correct format in the born column
    correct_format = r"^(\d{2})-([A-Z]{1}[a-z]{2})-(\d{4})$"

    # Store incorrect formats and correction counts in a dict
    incorrect_formats = {
        "dd-Mon-yy": [r"^(\d{2})-([a-zA-Z]{3})-(\d{2})$", 0],
        "yyyy-mm-dd":[r"^(\d{4})-(\d{2})-(\d{2})$", 0],
        "dd Month yyyy": [r"^(\d{1,2}) ([a-zA-Z]{3,}) (\d{4})$", 0],
        "Month yyyy": [r"^([a-zA-Z]{3,}) (\d{4})$", 0],
        "yyyy": [r"^(\d{4})$", 0],
        "Anything with yyyy": [r".*(\d{4}).*", 0]
    }
    # NOTE: The Format "Mon-##" is too ambiguous to correct reliably (## could be month or year),
    # so it will be set to empty, along with any other unrecognized formats and unexpected data
    invalid_count = 0

    # Count of empty fields
    empty_count = 0

    # Store the month mapping for number to abbreviation
    month_num_map = {
        "01": "Jan",
        "02": "Feb",
        "03": "Mar",
        "04": "Apr",
        "05": "May",
        "06": "Jun",
        "07": "Jul",
        "08": "Aug",
        "09": "Sep",
        "10": "Oct",
        "11": "Nov",
        "12": "Dec"
    }

    # Loop through the data set
    for row in data_set[1:]:
        # The born column is the 4th coulmn (index 3)
        # Check if born is not in the correct format
        if not re.match(correct_format, row[3]):
            # Initialize the day, month and year
            day, month, year = "", "", ""
            # Initialize default values
            default_day = "01"
            default_month = "Jan"

            ## Check for each incorrect format

            # Test if it matches "dd-Mon-yy"
            if re.match(incorrect_formats["dd-Mon-yy"][0], row[3]):
                # Extract the day month, and year
                day, month, year = re.findall(incorrect_formats["dd-Mon-yy"][0], row[3])[0]
                # Convert the year to 4 digits, setting the year in the 1900s or 2000s, depending on the decade
                # If the decade is greater than 30, assume its the 1900s, else assume its the 2000s
                year = f"19{year}" if int(year) > 30 else f"20{year}"
                incorrect_formats["dd-Mon-yy"][1] += 1
            # Test if it matches "yyyy-mm-dd"
            elif re.match(incorrect_formats["yyyy-mm-dd"][0], row[3]):
                # Extract the day month, and year
                year, month, day = re.findall(incorrect_formats["yyyy-mm-dd"][0], row[3])[0]
                # Convert the month number to the month abbreviation
                month = f"{month_num_map[month]}"
                incorrect_formats["yyyy-mm-dd"][1] += 1
            # Test if it matches "dd Month yyyy"
            elif re.match(incorrect_formats["dd Month yyyy"][0], row[3]):
                # Extract the day month, and year
                day, month, year = re.findall(incorrect_formats["dd Month yyyy"][0], row[3])[0]
                # Convert the month name to the month abbreviation
                month = month[:3]
                incorrect_formats["dd Month yyyy"][1] += 1
            # Test if it matches "Month yyyy"
            elif re.match(incorrect_formats["Month yyyy"][0], row[3]):
                # Extract the month and year
                month, year = re.findall(incorrect_formats["Month yyyy"][0], row[3])[0]
                # Convert the month name to the month abbreviation
                month = month[:3]
                # Set the default day
                day = default_day
                incorrect_formats["Month yyyy"][1] += 1
            # Test if it matches "yyyy"
            elif re.match(incorrect_formats["yyyy"][0], row[3]):
                # Since it is already the year, assign it directly
                year = row[3]
                # Set the default month and day
                month, day = default_month, default_day
                incorrect_formats["yyyy"][1] += 1
            # Test if it contains a year (matching the first year found)
            elif re.match(incorrect_formats["Anything with yyyy"][0], row[3]):
                # Extract the year
                year = re.findall(incorrect_formats["Anything with yyyy"][0], row[3])[0]
                # Set the default month and day
                month, day = default_month, default_day
                incorrect_formats["Anything with yyyy"][1] += 1
            # Test if it is empty
            elif row[3] == "":
                empty_count += 1
            # Since it is not empty or a recognized format, count it as invalid and set it to empty
            else:
                # print(f"Unrecognized date format: {row[3]}")
                row[3] = ""
                invalid_count += 1

            # If all date components are filled, reformat the born column to the correct format
            if day and month and year:
                # Zero-pad the day if needed (e.g., "6" -> "06")
                day = day.zfill(2)
                # Ensure month is properly capitalized (e.g., "jan" -> "Jan", "APRIL" -> "Apr")
                month = month[:3].capitalize()
                row[3] = f"{day}-{month}-{year}"
    
    # Summarize the corrections
    correction_total = sum([count for _, count in incorrect_formats.values()]) + invalid_count

    # print("Task 2 Corrections:")
    # print(f"'dd-Mon-yy':{incorrect_formats["dd-Mon-yy"][1]} ")
    # print(f"'yyyy-mm-dd':{incorrect_formats["yyyy-mm-dd"][1]} ")
    # print(f"'dd Month yyyy':{incorrect_formats["dd Month yyyy"][1]}")
    # print(f"'Month yyyy':{incorrect_formats["Month yyyy"][1]} ")
    # print(f"'yyyy':{incorrect_formats["yyyy"][1]} ")
    # print(f"'Anything with yyyy':{incorrect_formats["Anything with yyyy"][1]} ")
    # print(f"Invalid Fields: {invalid_count}")
    # print(f"Total Lines Cleaned: {correction_total}")
    # print(f"Empty Fields: {empty_count}")
    # print(f"Remaining:  {len(data_set)-1 - correction_total - empty_count}")
    # print(f"Percentage Cleaned: {((correction_total)/(len(data_set)-1))*100:.2f}%")

    print(f"Task 2: Cleaned {correction_total} records in athlete bio data\n")
    
    # Return the data set
    return data_set

# ========== END TASK 2 - STEPHAN ==========


    # Some data is missing; if that is the case, simply make the data empty (empty string)
    
    # Some data is incomplete (example has year only) or just not as expected...it is up to you to decide 
    # how to deal with these cases. Wherever possible, a reasonable estimate of the 
    # birthdate should be made.

    # TASK 2 - SARTHAK
    # Some data is missing; if that is the case, simply make the data empty (empty string)

    # for row in data_set:
    #     if row == 0:
    #         continue
            



# This function reads a csv file and return a list of lists
# each element of the returned list is a row in the csv file
# The first row is the header row
# Line ~95
def read_csv_file(file_name):
    data_set = []
    with open(file_name, mode='r', encoding="utf-8-sig") as file:  # Change back to utf-8-sig
        csv_reader = csv.reader(file)
        for row in csv_reader:
            data_set.append(row)
    return data_set

# This function writes out a list of lists to a csv file.
# each element of the list is a row in the csv file
# The first row is the header row

def write_csv_file(file_name, data_set):
    with open(file_name, mode='w', newline='', encoding="utf-8-sig") as file:  # Change back to utf-8-sig
        csv_writer = csv.writer(file)
        for row in data_set:
            csv_writer.writerow(row)

# ========== TASK 1 - HASAN: PARIS DATA INTEGRATION ==========
# This function adds Paris 2024 Olympic data to the main dataset
# It handles: 1) Adding new athletes (no duplicates)
#             2) Adding event results for Paris medallists
#             3) Adding new countries (keeping them sorted)
def integrate_paris_data(athlete_bios, athlete_event_results, olympic_countries):
    """Add Paris 2024 Olympic data to the datasets"""
    
    # TASK 1 - HASAN: Load Paris data files
    paris_athletes = read_csv_file("paris/athletes.csv")
    paris_medallists = read_csv_file("paris/medallists.csv")
    paris_nocs = read_csv_file("paris/nocs.csv")

    # TASK 1 - HASAN: Build set of medallist athlete codes (only add athletes with results)
    medallist_codes = set()
    for row in paris_medallists[1:]:
        code = row[18] if len(row) > 18 else ''
        if code:
            medallist_codes.add(code)

    # TASK 1 - HASAN: Build dictionary to track existing athletes for duplicate detection
    # Key = athlete name (uppercase), Value = athlete_id
    # This allows O(1) lookup time instead of O(n) searching through list
    athlete_name_to_id = {}
    for row in athlete_bios[1:]:  # Skip header
        athlete_id = row[0]
        name = row[1].strip().upper()
        athlete_name_to_id[name] = athlete_id
    
    # TASK 1 - HASAN: Dictionary to map Paris athlete codes to main dataset IDs
    # This is needed because Paris data uses different ID system
    paris_code_to_main_id = {}
    
    # TASK 1 - HASAN: Find next available IDs for new records
    next_athlete_id = max(int(row[0]) for row in athlete_bios[1:]) + 1
    next_result_id = max(int(row[5]) for row in athlete_event_results[1:]) + 1
    
    # TASK 1 - HASAN: STEP 1 - ADD PARIS ATHLETES (no duplicates)
    new_athletes_added = 0
    for row in paris_athletes[1:]:  # Skip header
        paris_code = row[0]
        original_name = row[2]  # Original format (e.g., "EVENEPOEL Remco")

        # TASK 1 - HASAN: Convert name for duplicate checking only
        # Handle names like "van AERT Wout" where lowercase prefix is part of lastname
        name_parts = original_name.split()
        converted_name = original_name
        if len(name_parts) >= 2:
            lastname_parts = []
            firstname_parts = []

            # Find last uppercase part - everything up to and including it is lastname
            last_upper_idx = -1
            for i, part in enumerate(name_parts):
                if part.isupper():
                    last_upper_idx = i

            if last_upper_idx >= 0:
                # Everything up to last uppercase is lastname, rest is firstname
                lastname_parts = name_parts[:last_upper_idx + 1]
                firstname_parts = name_parts[last_upper_idx + 1:]

                if lastname_parts and firstname_parts:
                    # Convert lastname to title case
                    lastname = ' '.join(p.title() if p.isupper() else p.title() for p in lastname_parts)
                    firstname = ' '.join(firstname_parts)
                    converted_name = f"{firstname} {lastname}"

        # TASK 1 - HASAN: Check for duplicates using converted name
        name_key = converted_name.strip().upper()

        # TASK 1 - HASAN: Use converted name format to match main dataset
        name = converted_name

        # TASK 1 - HASAN: Check if this athlete already exists in main dataset
        if name_key in athlete_name_to_id:
            # Duplicate found - just map their Paris code to existing ID
            paris_code_to_main_id[paris_code] = athlete_name_to_id[name_key]
            continue  # Don't add duplicate

        # TASK 1 - HASAN: New athlete - convert Paris format to main dataset format
        gender = row[5]
        # Main dataset uses "Male"/"Female", not "M"/"F"
        sex = gender if gender in ['Male', 'Female'] else ''
        birth_date = row[17] if len(row) > 17 else ''

        # TASK 1 - HASAN: Convert birth date from yyyy-mm-dd to dd-Mon-yyyy
        if birth_date and '-' in birth_date:
            date_parts = birth_date.split('-')
            if len(date_parts) == 3 and len(date_parts[0]) == 4:  # ISO format
                month_map = {'01':'Jan','02':'Feb','03':'Mar','04':'Apr','05':'May','06':'Jun',
                            '07':'Jul','08':'Aug','09':'Sep','10':'Oct','11':'Nov','12':'Dec'}
                year, month, day = date_parts
                month_abbr = month_map.get(month, month)
                birth_date = f"{day}-{month_abbr}-{year}"

        # TASK 1 - HASAN: Convert height/weight '0' to empty string (main dataset uses '' for missing)
        height = row[13] if len(row) > 13 and row[13] and row[13] != '0' else ''
        weight = row[14] if len(row) > 14 and row[14] and row[14] != '0' else ''

        # TASK 1 - HASAN: Add leading space to country (main dataset has " Bulgaria" format)
        country = ' ' + row[8] if len(row) > 8 and row[8] else ''
        country_noc = row[7] if len(row) > 7 else ''

        new_athlete = [str(next_athlete_id), name, sex, birth_date, height, weight, country, country_noc]
        athlete_bios.append(new_athlete)
        
        # TASK 1 - HASAN: Update both mappings
        paris_code_to_main_id[paris_code] = str(next_athlete_id)
        athlete_name_to_id[name_key] = str(next_athlete_id)
        next_athlete_id += 1
        new_athletes_added += 1
    
    print(f"Task 1: Added {new_athletes_added} new athletes from Paris 2024")
    
    # TASK 1 - HASAN: STEP 2 - ADD PARIS EVENT RESULTS
    paris_edition = "2024 Summer Olympics"  # FIXED: Must match olympics_games.csv
    paris_edition_id = "63"  # FIXED: Must match olympics_games.csv (row shows edition_id=63)
    new_results_added = 0
    skipped_results = 0
    
    for row in paris_medallists[1:]:  # Skip header
        code_athlete = row[18] if len(row) > 18 else ''
        
        # TASK 1 - HASAN: Skip if no athlete code
        if not code_athlete:
            skipped_results += 1
            continue
        
        # TASK 1 - HASAN: Check if we have this athlete mapped to a main ID
        if code_athlete not in paris_code_to_main_id:
            # Try to find by name as backup (some medallists might not be in Paris athletes file)
            name = row[3].strip().upper()
            if name in athlete_name_to_id:
                paris_code_to_main_id[code_athlete] = athlete_name_to_id[name]
            else:
                skipped_results += 1
                continue
        
        # TASK 1 - HASAN: Get the athlete ID and other result info
        athlete_id = paris_code_to_main_id[code_athlete]
        medal_type = row[1]
        name = row[3]
        country_noc = row[5]  # FIXED: row[5] is country_code (NOC), row[6] is country name
        sport = row[13]
        event = row[14]

        # TASK 1 - HASAN: Convert name format from "LASTNAME Firstname" to "Firstname Lastname"
        # Handle names like "van AERT Wout" where lowercase prefix is part of lastname
        name_parts = name.split()
        if len(name_parts) >= 2:
            # Find last uppercase part - everything up to and including it is lastname
            last_upper_idx = -1
            for i, part in enumerate(name_parts):
                if part.isupper():
                    last_upper_idx = i

            if last_upper_idx >= 0:
                lastname_parts = name_parts[:last_upper_idx + 1]
                firstname_parts = name_parts[last_upper_idx + 1:]

                if lastname_parts and firstname_parts:
                    lastname = ' '.join(p.title() if p.isupper() else p.title() for p in lastname_parts)
                    firstname = ' '.join(firstname_parts)
                    name = f"{firstname} {lastname}"

        # TASK 1 - HASAN: Convert medal type to format expected by main dataset
        medal = ''
        pos = ''
        if 'Gold' in medal_type:
            medal = 'Gold'
            pos = '1'
        elif 'Silver' in medal_type:
            medal = 'Silver'
            pos = '2'
        elif 'Bronze' in medal_type:
            medal = 'Bronze'
            pos = '3'
        
        # TASK 1 - HASAN: Check if this is a team sport using event_type field (index 15)
        # row[15] = event_type which is "TEAM", "HTEAM" for team events
        event_type = row[15] if len(row) > 15 else ''
        is_team = 'True' if event_type in ['TEAM', 'HTEAM'] else 'False'
        
        # TASK 1 - HASAN: Create new result record
        new_result = [paris_edition, paris_edition_id, country_noc, sport, event, 
                     str(next_result_id), name, athlete_id, pos, medal, is_team]
        athlete_event_results.append(new_result)
        next_result_id += 1
        new_results_added += 1
    
    print(f"Task 1: Added {new_results_added} event results from Paris 2024 (skipped {skipped_results})")
    
    # TASK 1 - HASAN: STEP 3 - ADD PARIS COUNTRIES (keep sorted, no duplicates)
    existing_nocs = {row[0] for row in olympic_countries[1:]}  # Build set of existing NOC codes
    new_countries = []
    
    for row in paris_nocs[1:]:  # Skip header
        noc_code = row[0]
        country_name = row[1]
        
        # TASK 1 - HASAN: Only add if NOT already in the dataset (e.g., ROC already exists)
        if noc_code not in existing_nocs:
            new_countries.append([noc_code, country_name])
            existing_nocs.add(noc_code)  # Add to set to prevent duplicates within Paris data too
    
    # TASK 1 - HASAN: Add new countries to list
    olympic_countries.extend(new_countries)
    
    # TASK 1 - HASAN: Sort countries alphabetically (keep header separate)
    header = olympic_countries[0]
    data = olympic_countries[1:]
    data.sort(key=lambda x: x[1].strip().upper())  # Sort by country name
    olympic_countries[:] = [header] + data
    
    print(f"Task 1: Added {len(new_countries)} new countries from Paris 2024")

      # TASK 1 - HASAN: Remove duplicate NOCs (keep only first occurrence)
    seen_nocs = set()
    unique_countries = [olympic_countries[0]]  # Keep header
    for row in olympic_countries[1:]:
        if row[0] not in seen_nocs:
            unique_countries.append(row)
            seen_nocs.add(row[0])
        else:
            print(f"Removed duplicate NOC: {row[0]}")

    olympic_countries[:] = unique_countries

# ========== END TASK 1 - HASAN ==========

# ========== START TASK 3 - SARTHAK ==========

def update_olympics_dates(olympic_games):
    """Update Paris 2024 dates in olympics_games"""
    for row in olympic_games[1:]:
        if '2024 Summer' in row[0]:
            # Paris 2024: July 26 - August 11
            row[7] = '26 July'
            row[8] = '11 August'
            row[9] = '26 July - 11 August'
    return olympic_games

def calculate_ages(athlete_event_results, athlete_bios, olympic_games):
    """Calculate age of athletes at time of olympics"""
    # Build lookup for athlete birth years
    athlete_births = {}
    for row in athlete_bios[1:]:
        athlete_id = row[0]
        born = row[3]
        if born:
            # Extract year from dd-Mon-yyyy format
            parts = born.split('-')
            if len(parts) == 3:
                try:
                    year = int(parts[2])
                    # Handle 2-digit years
                    if year < 100:
                        year = 1900 + year if year > 30 else 2000 + year
                    athlete_births[athlete_id] = year
                except:
                    pass

    # Build lookup for edition years
    edition_years = {}
    for row in olympic_games[1:]:
        edition = row[0]
        try:
            year = int(row[3])
            edition_years[edition] = year
        except:
            pass

    # Calculate ages
    for row in athlete_event_results[1:]:
        edition = row[0]
        athlete_id = row[7]

        if athlete_id in athlete_births and edition in edition_years:
            birth_year = athlete_births[athlete_id]
            event_year = edition_years[edition]
            age = event_year - birth_year
            if age > 0 and age < 100:
                row[11] = str(age)

    return athlete_event_results

def create_medal_tally_data(athlete_event_results):
    """Create medal tally summary"""
    # Dictionary to store tally: (edition, edition_id, noc) -> counts
    tally = {}

    # Track unique medals per event to avoid counting team members multiple times
    # Key: (edition, noc, event, medal_type)
    counted_medals = set()

    for row in athlete_event_results[1:]:
        edition = row[0]
        edition_id = row[1]
        noc = row[2]
        event = row[4]
        medal = row[9]
        athlete_id = row[7]

        key = (edition, edition_id, noc)
        if key not in tally:
            tally[key] = {'athletes': set(), 'gold': 0, 'silver': 0, 'bronze': 0}

        # Count athlete
        tally[key]['athletes'].add(athlete_id)

        # Count medals - only once per event/medal combination
        medal_key = (edition, noc, event, medal)
        if medal and medal_key not in counted_medals:
            counted_medals.add(medal_key)
            if medal == 'Gold':
                tally[key]['gold'] += 1
            elif medal == 'Silver':
                tally[key]['silver'] += 1
            elif medal == 'Bronze':
                tally[key]['bronze'] += 1

    # Convert to list
    result = [["edition", "edition_id", "Country", "NOC", "number_of_athletes",
               "gold_medal_count", "silver_medal_count", "bronze_medal_count", "total_medals"]]

    for (edition, edition_id, noc), counts in sorted(tally.items()):
        total = counts['gold'] + counts['silver'] + counts['bronze']
        if total > 0:  # Only include countries with medals
            result.append([
                edition, edition_id, '', noc,
                str(len(counts['athletes'])),
                str(counts['gold']), str(counts['silver']), str(counts['bronze']),
                str(total)
            ])

    return result

# Add a column to a data set
def add_column(data_set, column_name):
    #this will add the new column "age" to the "olympic_event_results.csv"

    # Append an empty column to the end of a data set
    for row in data_set:
        row.append("")
    # Set the column name
    data_set[0][-1] = column_name

    # Return the data set
    return data_set

# The entire point of this situation is to find out if birthday of the athletes were during the olympics or not.
def athlete_birthday_comparing_with_years_of_olympics(born, edition):
    # If the athletes are born after or during olympics, make it seem that they were born before the olympics began.
    # Another way to say my point is reduce it to before only that specific olympics, not all the olympics.
    if born.year == edition.year:
        age = age - 1
    # else born.year < edition.year or born.year > edition.year

    return age

# If the athlete's birthday is during the Olympics, 
# add the age as if their birthdate had happened before the Olympics began.
# age = born.year

def athlete_birthday_with_years_of_olympics(born, edition):
    if born.year >= edition.year:
        age = age - 1
    elif born.year is None or edition.year is None:
        print("Inorrect input, try again")

    return age

# This function writes out a list of lists to a csv file.
# each element of the list is a row in the csv file
# The first row is the header row

def write_csv_file(file_name, data_set):
    with open(file_name, mode='w', newline='', encoding="utf-8-sig") as file:  # Change back to utf-8-sig
        csv_writer = csv.writer(file)
        for row in data_set:
            csv_writer.writerow(row)

# This main function is the function that the runner will call
# The function prototype cannot be changed
def main():

    # Read from original CSV files
    athlete_bios = read_csv_file("olympic_athlete_bio.csv")
    athlete_event_results = read_csv_file("olympic_athlete_event_results.csv")
    olympic_countries = read_csv_file("olympics_country.csv")
    olympic_games = read_csv_file("olympics_games.csv")

    ## Task 1: Adding the Paris Data Olympics data
    # TASK 1 - HASAN: Call the Paris data integration function
    integrate_paris_data(athlete_bios, athlete_event_results, olympic_countries)

    ## Task 2: Cleaning the Data

    # Clean the athlete bio data
    athlete_bios = clean_athlete_bio_data(athlete_bios)

    ## Task 3: Adding Information
    #TASK 3 - SARTHAK
    # Add an "age" column to the athlete event results
    add_column(athlete_event_results, "age")

    # Update Paris 2024 dates
    olympic_games = update_olympics_dates(olympic_games)

    # Calculate ages for all athletes
    athlete_event_results = calculate_ages(athlete_event_results, athlete_bios, olympic_games)

    # Create medal tally summary
    medal_tally = create_medal_tally_data(athlete_event_results)

    # Write to new CSV files
    write_csv_file("new_olympic_athlete_bio.csv", athlete_bios)
    write_csv_file("new_olympic_athlete_event_results.csv", athlete_event_results)
    write_csv_file("new_olympics_country.csv", olympic_countries)
    write_csv_file("new_olympics_games.csv", olympic_games)
    write_csv_file("new_medal_tally.csv", medal_tally)
