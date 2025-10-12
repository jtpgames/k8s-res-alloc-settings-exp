# Memory

./run_teastore_experiment.sh --experiment-type memory-noisy-neighbor 

./run_teastore_experiment.sh --experiment-type memory-noisy-neighbor --ts-with-custom-res-conf memory_allocator_ts_with_on_demand_approach_partial_mem_resources

./run_teastore_experiment.sh --experiment-type memory-noisy-neighbor --ts-with-custom-res-conf memory_allocator_ts_with_on_demand_approach_mem_resources

./run_teastore_experiment.sh --experiment-type memory-noisy-neighbor --ts-with-custom-res-conf memory_allocator_ts_with_on_demand_approach_higher_limits_mem_resources

./run_teastore_experiment.sh --experiment-type memory-noisy-neighbor --ts-with-custom-res-conf memory_allocator_ts_with_on_demand_approach_higher_mem_resources

# CPU

./run_teastore_experiment.sh --experiment-type cpu-noisy-neighbor --ts-with-custom-res-conf cpu_load_generator_with_resources_teastore_with_webui_only_resources

./run_teastore_experiment.sh --experiment-type cpu-noisy-neighbor --ts-with-custom-res-conf cpu_load_generator_with_resources_teastore_with_example_resources

./run_teastore_experiment.sh --experiment-type cpu-noisy-neighbor --ts-with-custom-res-conf cpu_load_generator_with_resources_teastore_with_example_resources_and_limits

./run_teastore_experiment.sh --experiment-type cpu-noisy-neighbor --ts-with-custom-res-conf cpu_load_generator_with_resources_and_limits_teastore_with_example_resources_and_limits

# create section 3 figures:

# set --scatter-plot
./analyze_all_logs.sh "Memory_experiment without_resources" "Memory_experiment with_resources"

# unset --scatter-plot
./analyze_all_logs.sh "CPU_experiment without_resources" "CPU_experiment with_resources"
