+++
title = 'Making Python Dance: with multi-processing'
date = 2024-04-15T11:06:50-04:00
draft = false
+++

## Multiprocessing in Python: Boosting Performance with Parallel Computing

In the realm of Python programming, optimizing performance is often a critical consideration, especially when dealing with computationally intensive tasks. Especially considering the fact that Python has a lot of overhead - being a high level language. Also, I am tired of hearing about Python being a slow language, which, in an apples-to-apples comparison with lower level languages: IT IS. 

![python-meme](/python-slow.jpg "pYtH0N sLoW")

However, there are ways to speed up your python programs. One powerful technique for improving performance is parallel computing, which involves executing multiple tasks simultaneously. In this article, we'll go through a real-world example of writing code to create an inventory level forecasting in a retail business. I am gonna keep the premise very simple, there is no Deep Learning being used here, nor is there gonna be a PySpark instance running on the cloud doing our computation for us. 

I can imagine that using the techniques in this article might be helpful if you are constrained to using Python for your project and perhaps using a parallel computing cluster on the cloud is too much of a overkill. Nonetheless, I have had great success cutting down runtimes of programs using multiprocessing in multiple different instances.

### Problem Statement

Imagine you're developing a tool for tracking and forecasting inventory levels in a retail business. Each product has a unique identifier, initial inventory, sales rate, restocking rate, and duration for which you want to forecast inventory levels. Your task is to generate an inventory forecast for each product, detailing the projected inventory levels over the specified duration, considering sales and restocking activities.

So, if you have initial inventory of 10 units of product A on a certain date (say 2024-01-01 : being our day zero), and customers buy 5 units of that product each day, 3 units get restocked each day, then you would run out of product on 2024-01-05. Such a forecasting schedule can come in handy to get a gauge for restock dates, appropriate quantities, and to run simulations for stocking store shelves. Of course, these stock numbers and data would probably be coming from inventory management systems and there might be Machine Learning models running which predict when an item is going to run out of stock, so this is just a very-very-very thin sliver of what a production system might do.

Doing this for 1000 Product SKUs is pretty much instantaneous, but performing the same computation for 50,000 SKUs across thousands of Retail Stores ends up being a costly operation. Again, this is just a toy problem, however, the principles of parallelizing computation can be applied to other situations. 

### The Importance of Multiprocessing

Forecasting inventory levels for multiple products can be a computationally intensive task, especially when dealing with a large number of products or a long forecasting duration. By leveraging multiprocessing, we can distribute the workload across multiple CPU cores, significantly reducing the time required to generate forecasts.

### The Solution: Leveraging Multiprocessing

To demonstrate the use of multiprocessing, let's consider a Python function generate_inventory_forecast_for_product that generates an inventory forecast for a single product. We'll parallelize the execution of this function for multiple products using the multiprocessing.Pool class.

Here's a version of a function which does the computation for a single product ID (SKU):

```
import multiprocessing
import datetime
import os

def generate_inventory_forecast_for_product(
    product_id: str,
    start_date: datetime.date,
    initial_inventory: float,
    sales_rate: float,
    restocking_rate: float,
    duration_days: int,
    frequency_of_update: int,
):
	"""
	Generate an inventory forecast for a product.

	Parameters:
	product_id (str): The unique identifier for the product.
	start_date (datetime.date): The start date of the inventory forecast.
	initial_inventory (float): The initial inventory level of the product.
	sales_rate (float): The rate at which the product is sold per day.
	restocking_rate (float): The rate at which the product is restocked per day.
	duration_days (int): The duration for which the inventory forecast is required, in days.
	frequency_of_update (int): The frequency of updating the inventory forecast, in days.
	report_date (datetime.date): The date for which the inventory forecast is reported.

	Returns:
	list: A list of dictionaries representing the inventory forecast for each update date.
		Each dictionary contains the following keys:
		- 'product_id': The unique identifier for the product.
		- 'update_date': The date of the inventory update.
		- 'inventory_level': The projected inventory level for the update date.
		- 'sales': The projected sales for the update date.
		- 'restocking': The projected restocking quantity for the update date.

	Example:
	product_id = 'ABC123'
	start_date = datetime.date(2024, 4, 1)
	initial_inventory = 100
	sales_rate = 5
	restocking_rate = 3
	duration_days = 30
	frequency_of_update = 1
	report_date = datetime.date(2024, 4, 15)

	forecast = generate_inventory_forecast(product_id, start_date, initial_inventory,
							sales_rate, restocking_rate,
							duration_days, frequency_of_update,
							report_date)
	"""
	inventory_level = initial_inventory
	inventory_forecast = []

	for day in range(duration_days):
		sales = sales_rate
		restocking = restocking_rate
		inventory_level -= sales
		inventory_level += restocking
		update_date = start_date + datetime.timedelta(days=frequency_of_update * day)

		row_dict = {
			"product_id": product_id,
			"update_date": update_date,
			"inventory_level": round(inventory_level, 2),
			"sales": round(sales, 2),
			"restocking": round(restocking, 2),
		}
		inventory_forecast.append(row_dict)
	
	return inventory_forecast

```

This is simple enough in terms of logic. Now, on to the interesting bit! We are going to be using Python's multiprocessing [module](https://docs.python.org/3/library/multiprocessing.html). The multiprocesing package and it's function bypass the GIL, as they spawn new Processes through the kernel. This results in true parallelism and is quite a bit different from the 'multithreading' package in Python. The 'multiprocessing' is better for CPU bound tasks whereas 'multithreading' is better for I/O bound tasks. This example of local computation is a CPU bound task and as requires 'multiprocessing', maybe I will make a post about threading in the future.

It is also important to note that for small sets of processing, using plain sequential execution can be quicker since there is overhead involving spawning of new processes by the OS. Just something to keep in mind next time you wanna parallelize this operation for 50 sets of repeated operations!


Our csv file (product_list.csv) looks something like this:

```
product_id,sell_start_date,initial_inventory,sales_rate,restocking_rate,duration_days,forecast_frequency
1,1/1/23,50,10,8,30,1
2,1/2/23,60,15,13,30,1
3,1/3/23,70,20,18,30,1
4,1/4/23,80,25,23,30,1
5,1/5/23,90,30,28,30,1
6,1/6/23,100,35,33,30,1
7,1/7/23,110,40,38,30,1
8,1/8/23,120,45,43,30,1
9,1/9/23,130,50,48,30,1
10,1/10/23,140,55,53,30,1
```

We will use pandas for convenience of reading and writing CSVs. Below we have a function which will call the `multiprocessing.Pool(processes=n)` with a context manager, where n is the number of processes Python will start for this operation. By default, if you leave it blank, it uses `os.cpu_count()` number of processes. I would honestly cap the number of processes below the value returned by `os.cpu_count()` since each new process spawned also does take up it's own memory and tend to be heavier than threads. The input into `.starmap()` is a list of lists containing with the nested lists containing the args into function `generate_inventory_forecast_for_product`.


```
def generate_inventory_forecasts_parallel(product_row):
    with multiprocessing.Pool(processes=os.cpu_count()) as pool:
        forecasts = list(pool.starmap(generate_inventory_forecast_for_product, product_row))

    forecast_outputs = []

    for product_list in forecasts:
        for item in product_list:
            forecast_outputs.append(item)

    return forecast_outputs
```

The driver script looks something like this:

```
# Example usage
if __name__ == "__main__":
    all_products = pd.read_csv("product_list.csv")
    all_products["sell_start_date"] = pd.to_datetime(all_products["sell_start_date"]).dt.date
    all_products = all_products.values.tolist()

    forecasts = generate_inventory_forecasts_parallel(all_products)

	forecast_df = pd.DataFrame(forecasts)
    forecast_df.to_csv("all_products_forecast.csv", index=False)

```

`forecasts` returned from the `generate_inventory_forecasts_parallel` function are a list of dictionaries and due to this reason Pandas can *slurp* it up very easily and give us a well structured output which can be easily exported to formats such as CSVs.

### Summary:

- `generate_inventory_forecast_for_product` is a function that generates an inventory forecast for a single product.
- `generate_inventory_forecasts_parallel` is a function that parallelizes the execution of `generate_inventory_forecast_for_product` for multiple products using multiprocessing.Pool.
- We read product data from a CSV file, prepare it as input for `generate_inventory_forecasts_parallel`, and then call the function to generate inventory forecasts in parallel.

By distributing the workload across multiple CPU cores, we can achieve significant performance improvements, especially when dealing with large datasets or complex computations. Multiprocessing is a powerful technique for improving the performance of computationally intensive Python programs by leveraging parallelism. By distributing tasks across multiple processes, it allows us to take full advantage of modern multi-core processors, leading to faster execution times and improved scalability. 


