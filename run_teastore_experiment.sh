function create_and_activate_venv_in_current_dir {
  # Check if the "venv" folder exists
  if [ ! -d "venv" ]; then
      echo "The 'venv' folder does not exist. Creating a virtual environment..."
      # Create a virtual environment named "venv"
      python3 -m venv venv

      # Check if the virtual environment was created successfully
      if [ $? -eq 0 ]; then
          echo "Virtual environment 'venv' created successfully."
      else
          echo "Failed to create virtual environment 'venv'. Exiting."
          exit 1
      fi
  else
      echo "The 'venv' folder already exists."
  fi

  # Activate the virtual environment
  source venv/bin/activate

  echo "installing python requirements"
  pip install wheel
  pip install --upgrade pip setuptools
  if [ -f local_requirements.txt ]; then
    pip install -r local_requirements.txt
  else
    pip install -r requirements.txt
  fi

  # Check if the virtual environment was activated successfully
  if [ $? -eq 0 ]; then
      echo "Virtual environment 'venv' activated successfully."
  else
      echo "Failed to activate the virtual environment 'venv'. Exiting."
      exit 2
  fi
}

echo "locust_scripts:"
cd locust_scripts
create_and_activate_venv_in_current_dir

cd ..

echo "All Python virtual environments created and requirements installed."

# perform a few requests to warm up the service (a real warmup is performed by the load test later,
# this is just a start,
# because we observed that sometimes the load balancer of TeaStore gets stuck.

cluster_ip="165.227.247.126"

for i in {1..20}
do
  curl "http://$cluster_ip/tools.descartes.teastore.webui/status"
  sleep 0.1
  curl "http://$cluster_ip/tools.descartes.teastore.webui/"
  sleep 0.1
  curl "http://$cluster_ip/tools.descartes.teastore.webui/login"
  sleep 0.1
  curl "http://$cluster_ip/tools.descartes.teastore.webui/category?category=2&page=1"
  sleep 0.1
  curl "http://$cluster_ip/tools.descartes.teastore.webui/product?id=7"
  sleep 0.1
  curl "http://$cluster_ip/tools.descartes.teastore.webui/profile"
  sleep 0.1
done

cd locust_scripts
export KEEP_TEASTORE_LOGS=True
./start_teastore_loadtest.sh --ip $cluster_ip --no_port
