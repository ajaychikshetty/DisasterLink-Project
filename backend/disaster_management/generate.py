import pathlib

# --- Configuration ---
# Set the path to the main directory containing your folders.
# Use '.' to represent the current directory where the script is running.
root_dir_path = pathlib.Path('.') 
# ---------------------

# Check if the specified directory exists
if not root_dir_path.exists() or not root_dir_path.is_dir():
    print(f"Error: The directory '{root_dir_path}' does not exist or is not a directory.")
else:
    # Iterate through all items (folders, files) in the root directory
    for sub_dir in root_dir_path.iterdir():
        # Process only if the item is a directory
        if sub_dir.is_dir():
            print(f"Processing directory: '{sub_dir.name}'...")
            
            # Define the name and path for the new output file (e.g., 'folder1/folder1.txt')
            output_file_path = sub_dir / f'{sub_dir.name}.txt'
            
            # A list to store the formatted content from each file
            all_contents = []
            
            # Iterate through all files inside the sub-directory
            for file_path in sub_dir.iterdir():
                # Process only if it's a file and not the output file we are creating
                if file_path.is_file() and file_path != output_file_path:
                    try:
                        # Read the content of the file
                        content = file_path.read_text(encoding='utf-8')
                        
                        # Format the content as "filename:\ncontent"
                        formatted_content = f"{file_path.name}:\n{content}"
                        all_contents.append(formatted_content)
                    except Exception as e:
                        print(f"  - Could not read file '{file_path.name}': {e}")
            
            # Join all the collected contents with a blank line in between
            final_output = "\n\n".join(all_contents)
            
            # Write the final combined content to the new file
            try:
                output_file_path.write_text(final_output, encoding='utf-8')
                print(f"  -> Successfully created '{output_file_path.name}'")
            except Exception as e:
                print(f"  -> Error writing to '{output_file_path.name}': {e}")

    print("\nScript finished.")