#include <iostream>
#include <vector>
#include <random>

using namespace std;

int n = 3;
int m = 5;

vector<vector<int>> matrixn(n, vector<int>(m, 0));
vector<vector<int>> transposedmatrix(m, vector<int>(n, 0));

void transpose();

void run_ex02_18() 
{
	

	std::random_device rd;  
	std::mt19937 gen(rd()); 
	std::uniform_int_distribution<int> dist(0, 10);  

	for (int i = 0; i < n; i++)
	{
		for (int j = 0; j < m; j++)
		{
			matrixn[i][j] = dist(gen);
		}
	}

	transpose();

	cout << "--- origin matrix ---" << endl;

	for (int i = 0; i < n; i++)
	{
		cout << "[";
		for (int j = 0; j < m; j++)
		{
			cout << matrixn[i][j] << " " ;
		}
		cout << "]" << endl;
	}

	cout << endl << "--- transposed matrix ---" << endl;
	for (int i = 0; i < m; i++)
	{
		cout << "[";
		for (int j = 0; j < n; j++)
		{
			cout << transposedmatrix[i][j] << " ";
		}
		cout << "]" << endl;
	}
}

void transpose()
{
	for (int i = 0; i < n; i++)
	{
		for (int j = 0; j < m; j++)
		{
			transposedmatrix[j][i] = matrixn[i][j];
		}
	}
}