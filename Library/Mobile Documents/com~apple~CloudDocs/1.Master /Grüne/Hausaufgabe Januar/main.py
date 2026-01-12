import psycopg2
import pandas as pd
import matplotlib.pyplot as plt

# Connection parameters as a mapping (dict). psycopg2.connect(**params) requires a mapping.
params = {
        "host": "localhost",
        "database": "pagila_dwh",
        "user": "postgres",
        "password": "Harri58473!",  # UPDATE THIS with the correct password
}

# Open connection once and reuse
try:
    conn = psycopg2.connect(**params)
    cursor = conn.cursor()
except psycopg2.OperationalError as e:
    print(f"Connection Error: {e}")
    print("\nPlease verify:")
    print("- Host: localhost")
    print("- Database: pagila_dwh") 
    print("- User: postgres")
    print("- Password: Check pgAdmin settings for correct password")
    exit()
cursor.execute("SELECT COUNT(*) FROM vw_rental_analysis")
print(f"Total records: {cursor.fetchone()[0]}")
query = """
SELECT film_category,
        COUNT(*) AS total_rentals,
        SUM(rental_amount) AS total_revenue
FROM vw_rental_analysis
GROUP BY film_category
ORDER BY total_rentals DESC;
"""

df = pd.read_sql(query, conn)

# Print a concise table to the console
print("\nRentals by Film Category:\n")
print(df.to_string(index=False))

# Display an interactive bar chart (will open a window on your machine)
plt.figure(figsize=(10, 6))
plt.bar(df["film_category"], df["total_rentals"], color="tab:blue")
plt.title("Rentals by Film Category")
plt.xlabel("Film Category")
plt.ylabel("Total Rentals")
plt.xticks(rotation=45, ha="right")
plt.tight_layout()
plt.show()
# Generate rental trends over time (Report 2)
def generate_rental_trends(connection):
        """Query vw_rental_analysis grouped by year/month and display a line chart."""
        sql = """
        SELECT year, month, month_name,
                   COUNT(*) AS total_rentals,
                   SUM(rental_amount) AS total_revenue
        FROM vw_rental_analysis
        GROUP BY year, month, month_name
        ORDER BY year, month;
        """
        df_time = pd.read_sql(sql, connection)

        if df_time.empty:
                print("No time-series data found in vw_rental_analysis.")
                return

        # Create a proper datetime for plotting (use first day of month)
        df_time["year"] = df_time["year"].astype(int)
        df_time["month"] = df_time["month"].astype(int)
        df_time["period"] = pd.to_datetime(df_time[ ["year", "month" ] ].assign(day=1))

        # Print a concise table to the console
        print("\nRental trends (monthly):\n")
        print(df_time[["year", "month", "month_name", "total_rentals", "total_revenue"]].to_string(index=False))

        # Line chart (total_rentals over time)
        plt.figure(figsize=(12, 6))
        plt.plot(df_time["period"], df_time["total_rentals"], marker="o", linestyle="-", color="tab:green")
        plt.title("Rental Trends Over Time (Total Rentals)")
        plt.xlabel("Time")
        plt.ylabel("Total Rentals")
        plt.grid(True, linestyle='--', alpha=0.5)
        plt.tight_layout()
        plt.gcf().autofmt_xdate()
        plt.show()


generate_rental_trends(conn)

conn.close()

