#!/usr/bin/awk -f
# toCobertura.awk - Main script to convert LCOV to Cobertura XML

BEGIN {
    # Initialize variables
    timestamp = systime()
    lines_total = 0
    lines_covered = 0
    branches_total = 0
    branches_covered = 0
    
    # Print XML header
    print "<?xml version=\"1.0\" ?>"
    print "<!DOCTYPE coverage SYSTEM 'http://cobertura.sourceforge.net/xml/coverage-04.dtd'>"
    print "<coverage version=\"2.0.3\" timestamp=\"" timestamp "\">"
    print "  <sources>\n    <source>" base_dir "</source>\n  </sources>"
    print "  <packages>"
}

/^SF:/ {
    if (current_file != "") {
        output_file_data()
    }
    
    current_file = substr($0, 4)
    relative_file = current_file
    
    # Make path relative to base_dir by removing base_dir prefix and leading slash
    if (base_dir != ".") {
        if (index(relative_file, base_dir) == 1) {
            relative_file = substr(relative_file, length(base_dir) + 2)
        }
    }
    
    split(relative_file, path_parts, "/")
    package_name = ""
    for (i = 1; i < length(path_parts); i++) {
        if (package_name != "") package_name = package_name "."
        package_name = package_name path_parts[i]
    }
    
    class_name = relative_file
    gsub("/", ".", class_name)
    
    # Reset counters
    delete lines
    delete branches
    file_lines_total = 0
    file_lines_covered = 0
    file_branches_total = 0
    file_branches_covered = 0
}

/^DA:/ {
    split(substr($0, 4), data, ",")
    line_num = data[1]
    hits = data[2]
    
    lines[line_num]["hits"] = hits
    lines[line_num]["branch"] = "false"
    file_lines_total++
    if (hits > 0) file_lines_covered++
}

/^BRDA:/ {
    split(substr($0, 6), data, ",")
    line_num = data[1]
    block_num = data[2]
    branch_num = data[3]
    branch_hits = data[4]
    
    if (!(line_num in branches)) {
        branches[line_num]["total"] = 0
        branches[line_num]["covered"] = 0
        lines[line_num]["branch"] = "true"
    }
    
    branches[line_num]["total"]++
    file_branches_total++
    if (branch_hits != "-" && branch_hits > 0) {
        branches[line_num]["covered"]++
        file_branches_covered++
    }
}

END {
    if (current_file != "") {
        output_file_data()
    }
    
    print "  </packages>"
    print "</coverage>"
}

function output_file_data() {
    if (!package_started) {
        print "    <package name=\"" package_name "\" line-rate=\"" calc_rate(file_lines_covered, file_lines_total) "\" branch-rate=\"" calc_rate(file_branches_covered, file_branches_total) "\" complexity=\"0\">"
        print "      <classes>"
        package_started = 1
    }
    
    print "        <class name=\"" class_name "\" filename=\"" relative_file "\" line-rate=\"" calc_rate(file_lines_covered, file_lines_total) "\" branch-rate=\"" calc_rate(file_branches_covered, file_branches_total) "\" complexity=\"0\">"
    print "          <methods/>"
    print "          <lines>"
    
    # Output lines
    for (line_num in lines) {
        branch_attr = lines[line_num]["branch"]
        hits = lines[line_num]["hits"]
        
        printf "            <line number=\"%d\" hits=\"%d\" branch=\"%s\"", line_num, hits, branch_attr
        
        if (line_num in branches) {
            total = branches[line_num]["total"]
            covered = branches[line_num]["covered"]
            percentage = int((covered * 100.0) / total)
            printf " condition-coverage=\"%d%% (%d/%d)\"", percentage, covered, total
        }
        
        print "/>"
    }
    
    print "          </lines>"
    print "        </class>"
    
    lines_total += file_lines_total
    lines_covered += file_lines_covered
    branches_total += file_branches_total
    branches_covered += file_branches_covered
}

function calc_rate(covered, total) {
    if (total == 0) return "0.0"
    return covered / total
}
