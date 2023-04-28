#!/usr/bin/env python3

import random
import string
import argparse

######### FUNCTIONS #########
def generate_random_string(length):
    characters = string.ascii_uppercase + string.digits
    weights = [1]*26 + [2]*10 # set weights for uppercase letters and digits
    return ''.join(random.choices(characters, k=length, weights=weights))

def existing_dup(random_string, filename): 
    #filename here refers to the txt file recording the already generated random strings assigned as analysis IDs
    #return False only if the random string generated is not in the txt file
    try:
        with open(filename, 'r') as f:
            lines = f.readlines()
            header = lines[0].strip().split('\t')
            if len(header) != 2 or header[0] != 'analysis_ID':
                raise ValueError('File must have two columns with header "analysis_ID" in the first column')
            if len(lines) > 1:
                for line in lines[1:]:    
                    fields = line.strip().split('\t')
                    if len(fields) != 2:
                        raise ValueError('File must have two columns')
                    elif random_string == fields[0]:
                        return True
            return False                        
    except Exception as e:
        print(f'Error: {e}')
    
def generate_id(length, filename):
    while True:
        random_string = generate_random_string(length)
        if not existing_dup(random_string, filename):
            break    
    return random_string

######### MAIN #########
if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('length', help='length of alphanumeric string to generate')
    parser.add_argument('--filename', default="./analysis_id_list.txt", help='path to file containing a list of alphanumeric strings')
    args = parser.parse_args()
    
    length = int(args.length)
    filename = args.filename
    random_string = generate_id(length, filename)

    print(random_string)
