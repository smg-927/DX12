#include <iostream>
#include <vector>
#include <random>

using namespace std;

vector<vector<int>> matrix(4, vector<int>(4, 0));
vector<vector<float>> inversedmatrix(4, vector<float>(4, 0));
int CalcDeterminant3(int i, int j);
int CalcDeterminant();
int CalcDeterminant2(vector<vector<int>> mat);
void Calcinversedmatrix(int deter);

void run_ex02_19()
{
	std::random_device rd;
	std::mt19937 gen(rd());
	std::uniform_int_distribution<int> dist(-5, 5);

	for (int i = 0; i < 4; i++)
	{
		for (int j = 0; j < 4; j++)
		{
			matrix[i][j] = dist(gen);
		}
	}

	int determinant = CalcDeterminant();

	Calcinversedmatrix(determinant);

	cout << "--- origin matrix ---" << endl;

	for (int i = 0; i < 4; i++)
	{
		cout << "[";
		for (int j = 0; j < 4; j++)
		{
			cout << matrix[i][j] << " ";
		}
		cout << "]" << endl;
	}

	cout << "Determinant : " << determinant << endl;

	cout << endl << "--- inversed matrix ---" << endl;
	for (int i = 0; i < 4; i++)
	{
		cout << "[";
		for (int j = 0; j < 4; j++)
		{
			cout << inversedmatrix[i][j] << " ";
		}
		cout << "]" << endl;
	}
}
int CalcDeterminant()
{
	return matrix[0][0] * CalcDeterminant3(0, 0)
		 - matrix[0][1] * CalcDeterminant3(0, 1)
		 + matrix[0][2] * CalcDeterminant3(0, 2)
		 - matrix[0][3] * CalcDeterminant3(0, 3);
}

int CalcDeterminant3(int i, int j)
{
	vector<vector<int>> tmpmatrix(3, vector<int>(3, 0));

	int xindex = 0; 

	for (int x = 0; x < 4; x++)
	{
		if (x == i)
		{
			continue;
		}
		
		int yindex = 0;

		for (int y = 0; y < 4; y++)
		{
			if (y == j)
			{
				continue;
			}

			tmpmatrix[xindex][yindex] = matrix[x][y];
			yindex++;
		}
		xindex++;
	}

	return CalcDeterminant2(tmpmatrix);
}

int CalcDeterminant2(vector<vector<int>> mat)
{

	int returnvalue = 0;

	returnvalue += mat[0][0] * (mat[1][1] * mat[2][2] - mat[1][2] * mat[2][1]);
	returnvalue -= mat[0][1] * (mat[1][0] * mat[2][2] - mat[1][2] * mat[2][0]);
	returnvalue += mat[0][2] * (mat[1][0] * mat[2][1] - mat[1][1] * mat[2][0]);

	return returnvalue;
}

void Calcinversedmatrix(int deter)
{
	for (int i = 0; i < 4; i++)
	{
		for (int j = 0; j < 4; j++)
		{
			float sign = ((i + j) % 2 == 0) ? 1.0f : -1.0f;
			float cofactor = sign * CalcDeterminant3(i, j);
			inversedmatrix[j][i] = cofactor / float(deter);  // ← 전치된 위치에 대입!
		}
	}
}