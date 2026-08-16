int increasedQuantity(int current) => current + 1;

int decreasedQuantity(int current) => current > 1 ? current - 1 : 1;

bool canDecreaseQuantity(int current) => current > 1;
