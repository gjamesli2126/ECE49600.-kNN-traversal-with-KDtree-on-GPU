#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <cuda_runtime.h>
#include <device_launch_parameters.h>
#include <math.h>
#include <stdbool.h>
#include <setjmp.h>


#define TREE_space_extra_buff 4
#define point_space_extra_buff 8
#define COUNT 20

#define DATASET_NUM 9
#define MAX_INT_DEF 0xfffffff
#define max_clock_stamp 0xfffffff
#define max_clock_store 16
#define DIM 3
jmp_buf jmpbuffer;
clock_t run_time_debug[max_clock_store];
int clock_index=0;
bool write_Data_head = false;
unsigned long long  store_avi_node_num=0;
typedef struct point{
    float values[DIM];
    float th;//store distance or quantity
}point;
typedef struct node{
    point data;
    struct node* left=NULL;
    struct node* right=NULL;
}node;
unsigned long long mypow(int x, int y) {
    unsigned long long result = 1;
    int i;
    for (i = 0; i < y; i++) {
        result *= x;
    }
    //    printf("%llu",result);
    return result;
}
void print_nD_arr(point* arr){
    int size=(int)roundf(arr[0].th);//roundf: in order to make sure floating error does not affect size number!
    printf("index");
    for (int k = 0; k <DIM ; ++k) printf("\t\tdata[%d]\t",k);
    printf("\t\tth/dist\n");

    for (int i = 0; i <=size ; ++i) {
        printf("%d\t\t",i);
        for (int j = 0; j <DIM ; ++j) {
            printf("%f\t\t",arr[i].values[j]);
        }
        printf("%d\n",(int)arr[i].th);
    }
}
void print_this_point_woth(point thispoint){
    printf("(");
    for (int i = 0; i <DIM ; ++i) printf("%.1f, ",thispoint.values[i]);
    printf("\b\b)");
}
__device__
void print_this_point_woth_gpu(point thispoint) {
    printf("(");
    for (int i = 0; i < DIM; ++i) printf("%.1f, ", thispoint.values[i]);
    printf("\b\b)");
}
void print_this_point(point thispoint){
    printf("(");
    for (int i = 0; i <DIM ; ++i) printf("%.1f, ",thispoint.values[i]);
    printf("\b\b)_");
    printf("%.1f",thispoint.th);
    printf("\n");
}
void swap(point *x,point *y){
    point tmp;
    tmp=*x;
    *x=*y;
    *y=tmp;
}
point *super_gen_seq_arr(int number,bool reversed){
    int i,dim,j;
    point *arr=(point*)malloc(sizeof(point)*(number+1));
    for (i = 1; i <=number ; i++) {
        j=i;
        if(reversed==true) {
            j=number-i+1;
        }
        for (dim = 0; dim <DIM ; dim++) {
            arr[i].values[dim]=(float)(dim*100+j);//init
        }
        arr[i].th=MAX_INT_DEF;//init
    }
    arr[0].th=number;
    return arr;
}
point *super_gen_rand_arr(int number,int max){
    srand(time(NULL));
    int i,dim;
    point *arr=(point*)malloc(sizeof(point)*(number+1));
    for (i = 1; i <=number ; i++) {
        for (dim = 0; dim <DIM ; dim++) {
            arr[i].values[dim]=(float)(rand() % (max+1));//should use this

//            arr[i].values[dim]=((float)(rand()%100));//init
        }
        arr[i].th=MAX_INT_DEF;//init
    }
    arr[0].th=number;
    return arr;
}
point* deep_copy(point *arr){
    int size=(int)roundf(arr[0].th);
    point* newarr=(point*)malloc(sizeof(point)*(size+1));
    memcpy(newarr,arr, sizeof(point)*(size+1));
    return newarr;
}
int print_test_qsort(point* arr){
    int val=0;
    for (int i = 1; i <=(int)roundf(arr[0].th) ; ++i) {
        val+=mypow(10,(int)roundf(arr[0].th)-i)*(int)arr[i].values[0];
    }
    return val;
}
void quicksort(point *orgarr,int first,int last,int for_which_dim){
    int from_first,from_last,pivot;
//    int testing;
//    int test_from_first_val;
//    int test_from_last_val;
//    int test_pivot_val;
//    testing=print_test_qsort(orgarr);
    if(for_which_dim>DIM){
        printf("dim Err into quick sort\n");
        EXIT_FAILURE;
    }
    if(first<last){
        pivot=first;
        from_first=first;
        from_last=last;
        while(from_first<from_last){//if left index & right index not cross mid-> continue
            //if not normal-> move the index
            while((orgarr[from_first].values[for_which_dim]<=orgarr[pivot].values[for_which_dim])&&(from_first<last)) from_first++;
            //if not normal-> move the index
            while(orgarr[from_last].values[for_which_dim]>orgarr[pivot].values[for_which_dim]) from_last--;
            //            //if valid first and last index-> swap two chosen points (1 at right and another ar left)
            if(from_first<from_last)    swap(&orgarr[from_first],&orgarr[from_last]);
//            otherwise continue
//            printf("----\n");
//            print_nD_arr(orgarr);
//            usleep(1000000*1);
//            print_nD_arr(orgarr);
        }
        //change the pivot to the right side of the chosen point
        swap(&orgarr[pivot],&orgarr[from_last]);
        //insert node for right side of the tree
        quicksort(orgarr,first,from_last-1,for_which_dim);
        //insert node for left side of the tree
        quicksort(orgarr,from_last+1,last,for_which_dim);
    }
}
void print2DUtil(node *root, int space){
    if (root == NULL) return;
    int i;
    space += COUNT;

    print2DUtil(root->right, space);
    printf("\n");
    for (i = COUNT; i < space; i++) printf(" ");
    printf("(");
    for (i = 0; i <DIM ; i++) {
        printf("%.1f  ",root->data.values[i]);
    }
    printf(")\n");
//    printf("(%d,%d)\n", root->data.,root->data.y);
    print2DUtil(root->left, space);
}
void print_node(node* root){
    int i;

    printf("(");
    for (i = 0; i <DIM ; i++) {
        printf("%.1f ",root->data.values[i]);
    }
    printf(")th:%d\n",(int)roundf(root->data.th));
}
int print_bt(node* root){
    static int count=0;
    int i;
    if(root==NULL) return 0;
//    usleep(0.1*1000000);
    printf("(");
    for (i = 0; i <DIM ; i++) {
        printf("%.1f ",root->data.values[i]);
    }
    printf(")th:%d\n",(int)roundf(root->data.th));
    count++;
    print_bt(root->left);
    print_bt(root->right);
    return count;
}
int super_rand(int min,int max){
    srand(time(NULL));
    return rand()%(max+1-min)+min;
}
int find_mid_index(point* sorted_arr,point target,int chosen_dim){
    int i;
    for(i=1;i<=(int)sorted_arr[0].th;i++){
        if(sorted_arr[i].values[chosen_dim]>=target.values[chosen_dim]) return i-1;//previous index
    }
}
void show_time(char* str){
    run_time_debug[clock_index%max_clock_store]=clock();
    printf("%d____%d ms__ %s\n",clock_index,(int)(1000*(run_time_debug[clock_index%max_clock_store]-run_time_debug[((clock_index-1))%max_clock_store])/CLOCKS_PER_SEC),str);
    if(clock_index==max_clock_stamp) exit(10);
    clock_index++;
}
point* super_selection(point *orgarr,const char *up_down,int choose_dim,bool random_pick_med){
//    int portion=100/split_portion;// for annoy should change here! maybe: int->float//original
    // for GPU. Generate 32 kinds of portion
    //printf("--------new super selection----------\n");//orgprint

    int orgsorted_size=(int)roundf(orgarr[0].th);
    point *new_arr;
    int new_arr_size;
    int i;
    int mid_index;
    point mid_point;
    //orginial_arr_size is same as sorted_arr_size
//    show_time("initialize super_selection");
    point *sorted_orgarr=deep_copy(orgarr);
    quicksort(sorted_orgarr,1,orgsorted_size,choose_dim);
//    show_time("Quick sort");
//    if(orgarr[0].th<=3) random_pick_med=false;

    if (random_pick_med==true && (int)sorted_orgarr[0].th>1){
        //rand pick 2 points and calc the mean with random only pick an index with randonly pick 2 index
        int rindex1,rindex2;//index1 & index2
        point val1,val2;
        rindex1=super_rand(1,(int)sorted_orgarr[0].th);
//        show_time("find rindex1");
        do{
            rindex2=super_rand(1,(int)sorted_orgarr[0].th);
            if(rindex1==rindex2) rindex2= (rindex2+super_rand(0,(int)sorted_orgarr[0].th-2))%(int)sorted_orgarr[0].th+1;
                //org rindex2+- rand()
        }while(rindex1==rindex2);//randomed value cannot be the same//but condition variable is slow So this is just a backup plan
//        show_time("find rindex2");
        //printf("index=%d,%d\n",rindex1,rindex2);//orgprint
        //calc where should the index should be inserted in the array
        val1=sorted_orgarr[rindex1];
        val2=sorted_orgarr[rindex2];
        //find out the mid value
        for(i=0;i<DIM;i++) mid_point.values[i]=(val1.values[i]+val2.values[i])/2;//ignore the th value//FUTURE: can be simplify to one dim only
//        show_time("find virtual point");
        //find out the cutting index--with dim
        mid_index=find_mid_index(sorted_orgarr,mid_point,choose_dim);

        //printf("using %.1f as mid_index\n",((float)mid_index+0.5));//orgprint
//        show_time("find mid_index");

    }else if(!random_pick_med && (int)sorted_orgarr[0].th>1){
        mid_index = (int) ((1 + orgsorted_size) / 2);
        for(i=0;i<DIM;i++) mid_point.values[i]=((sorted_orgarr[mid_index].values[i]+sorted_orgarr[mid_index+1].values[i])/2);//deleted one or previous one
    }else if((int)sorted_orgarr[0].th<=1){
        new_arr=(point*)malloc(sizeof(point));//one point array
        new_arr[0].th=0;
        for(i=0;i<DIM;i++) new_arr[0].values[i]=sorted_orgarr[1].values[i];//deleted one or previous one
//        show_time("Edge-- End of leaf");
        return new_arr;
    }
    //for when only 1 element left
//    show_time("figure out mid_point & mid_split");
    if(strcmp(up_down,"down")==0){
//        printf("DOWN\n");
        new_arr_size=mid_index;
        new_arr=(point*)malloc(sizeof(point)*(1+new_arr_size));
        for(i=1;i<=new_arr_size;i++) new_arr[i]=sorted_orgarr[i];
        for(i=0;i<DIM;i++) new_arr[0].values[i]=mid_point.values[i];
//        show_time("down arr created!");
    }else if(strcmp(up_down,"up")==0){
//        printf("UP\n");
        new_arr_size=orgsorted_size-mid_index;// for annoy should change here!
        new_arr=(point*)malloc(sizeof(point)*(1+new_arr_size));
        for(i=1;i<=new_arr_size;i++) new_arr[i]=sorted_orgarr[mid_index+i];
        for(i=0;i<DIM;i++) new_arr[0].values[i]=mid_point.values[i];
//        show_time("up arr created!");
    }else{
        printf("Debug: arr is empty & super_selection failed!!!\n");
        exit(0);
    }

    new_arr[0].th=(float)new_arr_size;
    return new_arr;
}
node* convert_2_KDtree_code(point* arr, node* new_nodes, unsigned long long* node_index, float th, int brute_force_range, int chosen_dim, bool random_med) {
    if (new_nodes == NULL) {
        //handle error and rerun
        printf("Err handled!\n");
        longjmp(jmpbuffer, 1);
    }
    unsigned long long index_stamp = *node_index;
    //if (index_stamp==0) {
    //    printf("index_stamp%d \t\tstore_avi_node_num%d\n", index_stamp, store_avi_node_num);
    //}
    if (index_stamp > store_avi_node_num || index_stamp<0) {
        printf("index_stamp%d > store_avi_node_num%d\n", index_stamp, store_avi_node_num);
        longjmp(jmpbuffer, 2);
    }
    //    node* new_node=(node*)malloc(sizeof(node));
    point* arr_left;//=(point*) malloc(sizeof(point)*(arr[0].th+1));
    point* arr_right;//=(point*) malloc(sizeof(point)*(arr[0].th+1));
    int i;
    //    printf("\nEach recusrsion array\n");
    //    print_nD_arr(arr);
    chosen_dim++;
    chosen_dim %= DIM;
    //printf("Current Dim %d____node_index %d\n", chosen_dim, *node_index);//orgprint
    //    printf("updown st\n");
    arr_left = (super_selection(arr, "down", chosen_dim, random_med));//too slow!!!!!!!!!!!fix here----fixed!
    arr_right = (super_selection(arr, "up", chosen_dim, random_med));
    //    printf("updown End\n");
    //handle error
    new_nodes[index_stamp].data.th = th;
    if ((int)roundf(arr_left[0].th) >= brute_force_range) {
        for (i = 0; i < DIM; i++) new_nodes[index_stamp].data.values[i] = arr_left[0].values[i];
        //printf("L\n");//orgprint
        //print_nD_arr(arr_left);//orgprint
        //print_node(&new_nodes[index_stamp]);//orgprint
        (*node_index)++;
        new_nodes[index_stamp].left = convert_2_KDtree_code(arr_left, new_nodes, &(*node_index), th, brute_force_range, chosen_dim, random_med);
        free(arr_left);
    }
    else {
        for (i = 0; i < DIM; i++) new_nodes[index_stamp].data.values[i] = arr_left[0].values[i];
        //printf("L----NULL\n");////orgprint
        //print_nD_arr(arr_left);////orgprint
        //print_node(&new_nodes[index_stamp]);//orgprint
        new_nodes[index_stamp].left = NULL;
        free(arr_left);
    }
    if ((int)roundf(arr_right[0].th) >= brute_force_range) {
        for (i = 0; i < DIM; i++) new_nodes[index_stamp].data.values[i] = arr_right[0].values[i];
        //printf("R\n");////orgprint
        //print_nD_arr(arr_right);//orgprint
        //print_node(&new_nodes[index_stamp]);//orgprint
        (*node_index)++;
        new_nodes[index_stamp].right = convert_2_KDtree_code(arr_right, new_nodes, &(*node_index), th, brute_force_range, chosen_dim, random_med);
        free(arr_right);
    }
    else {
        for (i = 0; i < DIM; i++) new_nodes[index_stamp].data.values[i] = arr_right[0].values[i];
        //printf("R----NULL\n");//orgprint
        //print_nD_arr(arr_right);//orgprint
        //print_node(&new_nodes[index_stamp]);//orgprint
        new_nodes[index_stamp].right = NULL;
        free(arr_right);
    }
    //printf("------------------pop------------------------");//orgprint
    //printf("index_stamp: %d\n", index_stamp);//orgprint
    //if (index_stamp == 6) {};//debug only
    return &new_nodes[index_stamp];
}
int log2n(unsigned int n) {
    return (n > 1) ? 1 + log2n(n / 2) : 0;
}
unsigned long long calc_total_node_number(point* arr) {
    //    print_nD_arr(arr);
    unsigned long long buff;
    double log2x = log2n((int)arr[0].th);
    buff = pow(2, (int)((log2x)+1));
    
   
    //return 2 * buff + TREE_space_extra_buff;
    return buff - 1 + (int)arr[0].th + TREE_space_extra_buff;//normally the TREE_space_extra_buff should be zero!
//    return 2*(buff)-1-(buff-(int)arr[0].th)+TREE_space_extra_buff;//normally the TREE_space_extra_buff should be zero!
}
node* convert_2_KDtree(point* arr, bool random_med,unsigned long long rectify) {
    node* new_nodes;
    unsigned long long node_num, node_index;
    node_num = calc_total_node_number(arr)+rectify;
    //re-modify node_num
    store_avi_node_num = node_num;
    //printf("the node_number is: %d\n", node_num);//orgprint
    //new_nodes = (node*)malloc(sizeof(node) * node_num);
    cudaMallocManaged(&new_nodes, sizeof(node) * node_num);
    node_index = 0;

    return convert_2_KDtree_code(arr, new_nodes, &node_index, 1, 1, -1, random_med);
}
void push_front(point* org_arr,point desire_push,int k,bool k_full_lock){//k_full_lock: true to avoid element be popped if queue overflow!
//    printf("----------------------------------------------------\n");
    //need to update the arr[0].th as well!
    if(k_full_lock && k<=org_arr[0].th) return;
    int i;
    org_arr[0].th+=(float)(1-(int)(k<=(int)org_arr[0].th));
//    printf("%d\n",org_arr[0].th);
    for (i = (int)roundf(org_arr[0].th); i>1 ; i--) {
//        printf(" %d",i);
        org_arr[i]=org_arr[i-1];
    }
//    printf("\n");
    org_arr[1]=desire_push;
//    return org_arr;
}
void push_back(point* org_arr,point desire_push,int k, bool k_full_lock){//k_full_lock: true to avoid element be popped if queue overflow!
    if(k_full_lock && k<=(int)org_arr[0].th) return;
    int i;
    if(k<=(int)org_arr[0].th){
        for(i=1;i<(int)org_arr[0].th;i++) org_arr[i]=org_arr[i+1];
    }
    org_arr[0].th+=(float)(1-(int)(k<=(int)org_arr[0].th));
    org_arr[(int)org_arr[0].th]=desire_push;

}
void distance_calc(point target, point *on_leaf){
    double dist=0;
    int dim;
    for (dim = 0; dim <DIM ; dim++) {
        dist+= pow(target.values[dim]-on_leaf->values[dim],2);
    }
    dist=pow(dist,0.5);
    on_leaf->th=(float)dist;
//    return (float) dist;
}
__device__
void distance_calc_gpu(point target, point* on_leaf) {
    double dist = 0;
    int dim;
    for (dim = 0; dim < DIM; dim++) {
        dist += pow(target.values[dim] - on_leaf->values[dim], 2);
    }
    dist = pow(dist, 0.5);
    on_leaf->th = (float)dist;
    //    return (float) dist;
}
void k_nearest_search_code(int k,node* root,bool approximate,point target,int chosen_dim,point* nearest_points){
    //under occasion: approximate==true && only one point
    // this recursion is for approximate kNN search where k=1
    if(nearest_points[0].th>=(float)k) return;//return when have found k's element
    if(approximate) {
        if (root == NULL) return;
        else printf("--->%.1f", root->data.values[chosen_dim]);
        bool is_leaf = (root->left == NULL) && (root->right == NULL);
        if ((nearest_points[1].values[chosen_dim] != root->data.values[chosen_dim] || nearest_points[0].th == 0) &&
            (is_leaf)) {//(value comapre|| init)&&(is leaf)
            printf("S\t");//S means store!
            distance_calc(target, &root->data);
//            push_front(nearest_points, root->data, k,true);
            push_back(nearest_points, root->data, k,true);
        }//need modified when k>1
        if (target.values[chosen_dim] < root->data.values[chosen_dim]) {
            chosen_dim++;
            chosen_dim %= DIM;
            k_nearest_search_code(k, root->left, approximate, target, chosen_dim, nearest_points);
        } else {
            chosen_dim++;
            chosen_dim %= DIM;
            k_nearest_search_code(k, root->right, approximate, target, chosen_dim, nearest_points);
        }
    }else {
        if(chosen_dim==0) printf("\n");//for printing
        if (root == NULL) return;
        else{printf("----->(");for (int i = 0; i <DIM ; ++i) {printf("%.1f ", root->data.values[i]); }printf(")");}
        bool is_leaf = (root->left == NULL) && (root->right == NULL);
        if ((nearest_points[1].values[chosen_dim] != root->data.values[chosen_dim] || nearest_points[0].th == 0) && (is_leaf)) {//(value comapre|| init)&&(is leaf)
            printf("S\t");//S means store!
            distance_calc(target, &root->data);
//            push_front(nearest_points, root->data, k,true);
            push_back(nearest_points, root->data, k,true);
        }//need modified when k>1
        if (target.values[chosen_dim] < root->data.values[chosen_dim]) {
            chosen_dim++;
            chosen_dim %= DIM;
            k_nearest_search_code(k, root->left, approximate, target, chosen_dim, nearest_points);
            if(root->right!=NULL){
                k_nearest_search_code(k, root->right, approximate, target, chosen_dim, nearest_points);
            }
        } else {
            chosen_dim++;
            chosen_dim %= DIM;
            k_nearest_search_code(k, root->right, approximate, target, chosen_dim, nearest_points);
            if(root->left!=NULL){
                k_nearest_search_code(k, root->left, approximate, target, chosen_dim, nearest_points);
            }
        }
    }
}
point* k_nearest_search(int k,node* tree,bool approximate,point target){
    point* nearest_points=(point*)malloc(sizeof(point)*(k+1));
    nearest_points[0].th=0;
    printf("value searched(S:stored): ");
    k_nearest_search_code(k,tree,approximate,target,0,nearest_points);
    printf("\n");
    return nearest_points;
}
point k_nearest_search_wo_recursion_stack_k1_approx_code(node* root,point target){//return nearest_point
    node* current=root;
    int dim_count=0;
    printf("traverse route:");
    print_this_point_woth(current->data);
    while(current->left && current->right){
        if(current->data.values[dim_count]>target.values[dim_count] && current->left){
            current=current->left;
        } else if (current->data.values[dim_count]<=target.values[dim_count] && current->right){
            current=current->right;
        }
        else{
            if(current->left) current=current->left;
            else current=current->right;
        }
        dim_count++;
        dim_count%=DIM;
        printf("--->");
        print_this_point_woth(current->data);
        if(dim_count==0) printf("\n");
    }
    distance_calc(target,&current->data);
    printf("\n");
    return current->data;
}
__device__
void test_gpu_cancompile() {
    printf("Can!!!\n");
}
__global__ 
void k_nearest_search_k1_GPU(node** root,point target,int tree_num,point* point_list){//return nearest_point
    
    int i;// , route_store;
    int dim_count;
    //int debug;

    i = blockIdx.x * blockDim.x + threadIdx.x;
   // printf("\n----------------------thread------------------------------------%d\n", i);
    if(i<tree_num){
        if (root[i] == NULL) {
            printf("Null root skip!\n");
            return;
        }
        //printf("thread(%d) working!\n", i);//orgprint
        dim_count=0;
        while(root[i]->left && root[i]->right){
            if(root[i]->data.values[dim_count]>target.values[dim_count] && root[i]->left){
                root[i] = root[i]->left;
            } else if (root[i]->data.values[dim_count]<=target.values[dim_count] && root[i]->right){
                root[i] = root[i]->right;
            }
            else{
                if(root[i]->left) root[i] = root[i]->left;
                else root[i] = root[i]->right;
            }
            dim_count++;
            dim_count%=DIM;
        }
        distance_calc_gpu(target,&root[i]->data);
        point_list[i]= root[i]->data;
        /*debug = 4;*/
    }
}
point* k_nearest_search_wo_recusrion_stack(int k,node* tree,bool approximate,point target){
    point* nearest_points=(point*)malloc(sizeof(point)*(k+1));
    nearest_points[0].th=(float)k;
    int i;
    point onenearest;
    if(k==1 && approximate) {
        onenearest=k_nearest_search_wo_recursion_stack_k1_approx_code(tree,target);
//        print_this_point(onenearest);
        nearest_points[1]=onenearest;
    }
    else{
        printf("Sorry not yet finish this part yet!\n");
    }
    show_time("found the nearest point(s)");
    return nearest_points;
}
int gpu_kd_portion(int parallel_num,int scaling){//scaling=1~parallel_num
    return parallel_num/scaling;
}
void write_data_to_txt(char* fname,point* arr){
    FILE *f=fopen(fname,"w");
    if(f==NULL) exit(2);
    int k,i;

    fprintf_s(f,"%d %d\n",DIM,(int)arr[0].th);
    for (i = 1; i <=(int)arr[0].th ; ++i) {
//        fprintf_s(f,"%d\t\t",i);
        for (int j = 0; j <DIM ; ++j) {
            fprintf_s(f,"%f\t\t",arr[i].values[j]);
        }
        fprintf_s(f,"%d\n",(int)arr[i].th);
    }
    fclose(f);
}
point* read_data_from_txt(char* fname){
    FILE *f;
    char *orgarr;//have to mind the dataset length!!
    f=fopen(fname,"r+");
    if(f==NULL) exit(2);
    int dim,num_data,i,j;
    fscanf(f,"%d %d\n",&dim,&num_data);//second line to read info
    printf("dim:%d\tdatanum:%d\n",dim,num_data);
//    float buffdata[num_data+1][dim];
//    int buffth[num_data];
    point *input;
    input=(point*)malloc(sizeof(point)*(num_data+1));
    for(i=1;i<=num_data;i++){
        //perline
        for(j=0;j<dim;j++) fscanf(f,"%f\t\t",&input[i].values[j]);
        fscanf(f,"%f\n",&input[i].th);
    }
    fclose(f);
    input[0].th=(float)num_data;
    return input;
}
int calc_node_rounte_space_avg(int data_num) {
    return ((log(data_num) / log(2) + 1) + data_num) / 2;
}
void write_traverseresult_to_disk(char rn,int num_tree, unsigned long long num_queries, double time_taken, unsigned long long queries_max, unsigned long long  queries_min, unsigned long long  queries_interval, int block_num, int threads_num_per_block) {
    FILE* file;
    char buffer[128];
    char tmp[16];
    char fname_format[] = "%cblock_num%d,threads_per_block%d,treenum%d,quiers_max%llu,quiers_min%llu,quiers_interval%llu .txt";
    char fname[sizeof fname_format + 128];
    sprintf(fname, fname_format,rn,block_num,threads_num_per_block, num_tree, queries_max,queries_min,queries_interval);

    if (write_Data_head) {
        file = fopen(fname, "a");
        fprintf_s(file, " %d |  %llu |  %lf\n", num_tree, num_queries, time_taken);
    }
    else {
        write_Data_head = true;
        file = fopen(fname, "w");
        fprintf_s(file, "num_tree | num_queries | time_taken(s)\n");
    }
    /*//num_tree
    strcpy(buffer, "num_tree: ");
    itoa(num_tree, tmp, 10);
    strcat(buffer, tmp);
    
    //num_queries
    strcat(buffer, "  |  num_queries");
    ulltoa(num_queries, tmp, 10);
    strcat(buffer, tmp);

    //time_taken
    strcat(buffer, "  |  num_queries");
    sprintf(tmp, "%lf", time_taken);
    strcat(buffer, tmp);
    fprintf(file, "%s\n", buffer);*/

    fclose(file);
}
int main(){
    printf("process starts!\n");
    clock_t main_start;
    run_time_debug[0]=main_start=clock();
//    point* orgarr;
//    orgarr=super_gen_seq_arr(DATASET_NUM,true);
//    orgarr=super_gen_rand_arr(DATASET_NUM,48);
//    print_nD_arr(orgarr);//print!

//    test deepcopy--successful
/*
 * arr2=orgarr;//link
    arr2=deep_copy(orgarr);//deep copy
    arr2[0].values[0]=99999;
    print_nD_arr(orgarr);
 */
//    test swap & quick sort
/*

//    point* testarr=super_gen_seq_arr(7,true);
    point* testarr=super_gen_rand_arr(21);
//    testarr[0].values[0]=99999;testarr[0].values[1]=99999;
    print_nD_arr(testarr);
//    swap(&testarr[3],&testarr[6]);
    quicksort(testarr,1,21,2);
    printf("End\n");
    print_nD_arr(testarr);
*/
//test super_selection
/*

    printf("\n------------------------------------------------------------------\n");
    point* qsarr=deep_copy(orgarr);quicksort(qsarr,1,DATASET_NUM,0);print_nD_arr(qsarr);
    qsarr=deep_copy(orgarr);quicksort(qsarr,1,DATASET_NUM,1);print_nD_arr(qsarr);
    qsarr=deep_copy(orgarr);quicksort(qsarr,1,DATASET_NUM,2);print_nD_arr(qsarr);

    printf("\n------------------------------------------------------------------\n");
    print_nD_arr(super_selection(orgarr,"down",0,50));//print_nD_arr(selected);
    print_nD_arr(super_selection(orgarr,"down",1,50));//print_nD_arr(selected);
    print_nD_arr(super_selection(orgarr,"down",2,50));//print_nD_arr(selected);
    printf("\n------------------------------------------------------------------\n");
    print_nD_arr(super_selection(orgarr,"up",0,50));//print_nD_arr(selected);
    print_nD_arr(super_selection(orgarr,"up",1,50));//print_nD_arr(selected);
    print_nD_arr(super_selection(orgarr,"up",2,50));//print_nD_arr(selected);
*/
//test push
/*

    printf("------------test push\n");
    point target={{51,32,61},0};
    point target1={{1,32,61},0};
    point* org=malloc(sizeof(point)*4);

    push_front(org,target,3);print_nD_arr(org);
    push_front(org,target,3);print_nD_arr(org);
    push_front(org,target,3);print_nD_arr(org);
    push_front(org,target1,3);print_nD_arr(org);
    push_front(org,target1,3);print_nD_arr(org);
*/
//  test buliding KD tree //bug fixed//succeed
/*

    node *tree;
    tree=convert_2_KDtree(orgarr,50);//only code for 50, not yet solved other portions!
    print_bt(tree);
    print2DUtil(tree,0);
    */
//test approximate searching k=1
/*

    point target={{31,14,73},0};
    printf("%.1f,%.1f,%.1f\n",target.values[0],target.values[1],target.values[2]);
    point* found=k_nearest_search(1,tree,true,target);//true: approximate search
    print_nD_arr(found);
  */
//test distance correctness--succeed
/*
    //test distance correctness--succeed
    point p1={{3,7,2},0};
    point p2={{12,47,25},0};
    printf("ditance %.1f",distance_calc(p1,p2));
    exit(0);
*/
//test searching k>1-- approximate and back tracking both work
/*

    point target={{14,114,214},0};
    printf("%.1f,%.1f,%.1f\n",target.values[0],target.values[1],target.values[2]);
    point* found=k_nearest_search(5,tree,false,target);//true: approximate search
    print_nD_arr(found);
*/
//test push back
/*

    printf("------------test push\n");
    point target0={{51,32,61},0};
    point target1={{1,32,61},0};
    point* org=malloc(sizeof(point)*4);

    push_back(org,target0,3,false);print_nD_arr(org);
    push_back(org,target0,3,false);print_nD_arr(org);
    push_back(org,target0,3,false);print_nD_arr(org);
    push_back(org,target1,3,false);print_nD_arr(org);
    push_back(org,target1,3,false);print_nD_arr(org);
*/
//test rand_ find_mid_index
/*

    point target={{4.5,104.5,204.5},0};
    int chosen_index;
    chosen_index=find_mid_index(orgarr,target,0);
    printf("point shoud be at %d index",chosen_index);
*/
//build tree with specific portion
/*
    node *tree;
    run_time_debug[0]=clock();
    tree=convert_2_KDtree(orgarr,true);//for testing
    print_bt(tree);
    print2DUtil(tree,0);
    exit(0);
    point target={{14,114,214},0};
    printf("%.1f,%.1f,%.1f\n",target.values[0],target.values[1],target.values[2]);
    point* found=k_nearest_search(5,tree,false,target);//true: approximate search
    print_nD_arr(found);
*/
//These block tested with 4096 points & read write files & approximate precise search with random split KDtree
/*
    //ouput generated point!
//    write_data_to_txt("9points_rand_max39.txt",orgarr);

    //input generated data point
    point* gotarr;
    gotarr=read_data_from_txt("9points_rand_max39.txt");
    show_time("read dmn file");
    print_nD_arr(gotarr);
    show_time("print org arr");
    //test build ran_split KDtree
//    exit(clock()-main_start);
    node *tree;
    tree=convert_2_KDtree(gotarr,true);
    show_time("build tree time spent!");
    print_bt(tree);
    print2DUtil(tree,0);
    show_time("print tree");

    point target={{14,114,214},0};
    printf("%.1f,%.1f,%.1f\n",target.values[0],target.values[1],target.values[2]);
    //test kNN search with precise with k>1
    point* found=k_nearest_search(5,tree,false,target);//true: approximate search false: precise
    show_time("kNN precise");
    print_nD_arr(found);
    show_time("print found");

    printf("%.1f,%.1f,%.1f\n",target.values[0],target.values[1],target.values[2]);
    found=k_nearest_search(5,tree,true,target);//true: approximate search//k=1 as always
    show_time("kNN approximate");
    print_nD_arr(found);
    show_time("print found");
*/
//Traverse KD tree approximately with non-recursive & non-stack just one while loop k=1
/*
    //build tree from disk file

    node* tree;
    tree=convert_2_KDtree(read_data_from_txt("9points_rand_max39.txt"),true);
    print2DUtil(tree,0);
    show_time("tree print Fin");
    point target;
    point* nearest_points;
    int i;
    for(i=0;i<DIM;i++) target.values[i]=((i+1)*(rand()%43))%39;//test target point
    show_time("create_dependency Fin");
    nearest_points=k_nearest_search_wo_recusrion_stack(1,tree,true,target);
    show_time("kNN search fin");

    printf("target: ");print_this_point(target);
    print_nD_arr(nearest_points);
*/

//Generate trees & traverse with gpu
/*
//    point* orgarr=super_gen_rand_arr(8,144);//testing
//    write_data_to_txt("8points_rand_max144.txt",orgarr);//testing
    const int tree_num = 32;
    node** tree;
    cudaMallocManaged(&tree,sizeof(node)*tree_num);
    //node* tree[tree_num];
    int i;
    
    point* orgarr=read_data_from_txt("12pow_points_rand_max65535.txt");//NO: 13,14,15,16 ;PNO: 11, 12
    for(i=0;i<tree_num;i++) tree[i]=convert_2_KDtree(orgarr,true);
    free(orgarr);
    //orgprint
    //for(i=0;i<tree_num;i++) {
    //    print2DUtil(tree[i],0);
    //    printf("\n\n------------------------------------------------------\n\n\n\n\n");
    //}
    point target;
    point* found;

    target.values[0] = 33333;
    target.values[1] = 33333;
    target.values[2] = 11111;
    //printf("target point: ");
    //print_this_point_woth(target);
    //printf("\n");

    //GPU part--start!
    cudaMallocManaged(&found, sizeof(int) * (tree_num));
    clock_t traverse_start=clock();
    float time;
    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);
    cudaEventRecord(start, 0);
    k_nearest_search_k1_GPU << <20, tree_num >> > (tree, target, tree_num, found);
    cudaDeviceSynchronize();
    cudaEventRecord(stop, 0);
    cudaEventSynchronize(stop);
    cudaEventElapsedTime(&time, start, stop);
    //GPU part--END
    printf("ttraverse all trees time taken%3.6f ms\n", time);
    //show four points
    //printf("\n\n==============================\nfound:\n");
    //for(i=0;i<tree_num;i++){
    //    print_this_point(found[i]);
    //    printf("\n");
    //}
    cudaFree(found);
    */
// Final. Traverse methods change test.---try query points & tree_num & 1 block & N Threads
 /*
//original
    //int treeloop;
    int tree_num;
    int jmpVal;// skip error mem access
    //for(treeloop=8;treeloop>=7;treeloop--) {//control tree number
        //treeloop = 1;   
        //tree_num = mypow(2, treeloop);//2,4,8,16,32,64,128//,256
        tree_num = 32;
        node **tree;
        //cudaMallocManaged(&tree, sizeof(node) * max_tree_num);
        
        unsigned long long i;
        static unsigned long long rectify = 0;
        int j,previous_j,k;
        point *orgarr;
        

        unsigned long long queries_max = mypow(2, 14);//14
        unsigned long long queries_min = mypow(2, 2);
        unsigned long long loop_interval,queries_interval = mypow(2, 9);//9
        loop_interval = queries_interval;
        for (i = queries_max; i >= queries_min; i -= loop_interval) {//control query points number
            
            orgarr = super_gen_rand_arr(i, 65535);//generated immediately
            



            //orgarr = super_gen_seq_arr(i, false);
           
            cudaMallocManaged(&tree, sizeof(node) * (tree_num));
            for (j = 0; j < tree_num; j++) {
                jmpVal = setjmp(jmpbuffer);
                if (jmpVal == 0) {//norm case
                    

                    tree[j] = convert_2_KDtree(orgarr, true, rectify);
                    rectify = 0;
                    previous_j= j;

                }
                else if (jmpVal == 1) {// Null is return by CudaMallocManagement occur, skip, becasue excess Cuda ctrl's memory 
                    printf("newNodes is NULL!\n");
                    jmpVal = 0;
                    //j = store_j;
                    continue;
                }
                else if (jmpVal == 2) {//if allocated node memory insufficient
                    rectify++;
                    jmpVal = 0;
                    j = previous_j;//j->j-1
                    free(tree[j]);
                }

            }
            free(orgarr);
            //printf("traverse------------------------------------------------\n");
            point target;
            point* found;

            target.values[0] = 32751;
            target.values[1] = 33751;
            target.values[2] = 30000;
            //target.values[0] = 4096;
            //target.values[1] = 4196;
            //target.values[2] = 4296;
            //printf("target point: ");
            //print_this_point_woth(target);
            //printf("\nGPU part--start!\n");


            cudaMallocManaged(&found, sizeof(point) * (tree_num));//was sizeof(int)
            clock_t traverse_start = clock();
            float time;
            cudaEvent_t start, stop;
            cudaEventCreate(&start);
            cudaEventCreate(&stop);
            cudaEventRecord(start, 0);
            k_nearest_search_k1_GPU << < 1, tree_num >> > (tree, target, tree_num, found);
            //k_nearest_search_k1_GPU << < tree_num, 32 >> > (tree, target, tree_num, found);
            cudaDeviceSynchronize();//CPU stop

            cudaEventRecord(stop, 0);
            cudaEventSynchronize(stop);
            cudaEventElapsedTime(&time, start, stop);
            //GPU part--END

            printf("ttraverse all trees time taken%3.6f s\n", time);
            //show four points
            //printf("found:\n");
            //for (j = 0; j < tree_num; j++) {
            //    printf("%d\t", j);
            //    print_this_point(found[j]);
            //    printf("\n");
            //}


            //traverse---END
            cudaFree(found);//need
            //for (j = 0; j < tree_num; j++) {
            //    cudaFree(tree[j]);
            //}
            cudaFree(tree);//need
            //free(orgarr);
        //write text to disk here
            printf("\n\n\ntree number %d\tquery points number %llu, true interval %llu \n", tree_num, i,loop_interval);
            write_traverseresult_to_disk(tree_num, i, time,queries_max,queries_min,queries_interval);
            if ((i < 4 * loop_interval)&&(loop_interval!=1)) loop_interval /= 2;
        }

    */
//Final. Generate query points to compare performance in the future.
/*
    unsigned long long i;
    point* orgarr;
    unsigned long long queries_max = mypow(2, 14);//14
    unsigned long long queries_min = mypow(2, 2);
    unsigned long long loop_interval, queries_interval = mypow(2, 9);//9
    
    //write text
    char fname_format[] = "rand_queries_%llu.txt";
    char fname[sizeof fname_format + 128];
    


    loop_interval = queries_interval;

    for (i = queries_max; i >= queries_min; i -= loop_interval) {//control query points number
        orgarr = super_gen_rand_arr(i, 65535);//generated immediately
        sprintf(fname, fname_format, i);
        write_data_to_txt(fname, orgarr);
        if ((i < 4 * loop_interval) && (loop_interval != 1)) loop_interval /= 2;
        printf(".");
    }
    */
// Final. Traverse metods test; input data from disk. ->1 block  tree_num threads
/*
    int tree_num;
    int jmpVal;// skip error mem access
    tree_num = 32;
    node** tree;
    unsigned long long i;
    static unsigned long long rectify = 0;
    int j, previous_j, k;
    point* orgarr;
    unsigned long long queries_max = mypow(2, 14);//14
    unsigned long long queries_min = mypow(2, 2);
    unsigned long long loop_interval, queries_interval = mypow(2, 9);//9
    loop_interval = queries_interval;
    char fname_format[] = "rand_queries_%llu.txt";
    char fname[sizeof fname_format + 128];
    for (i = queries_max; i >= queries_min; i -= loop_interval) {//control query points number
        sprintf(fname, fname_format, i);
        orgarr = read_data_from_txt(fname);

        cudaMallocManaged(&tree, sizeof(node) * (tree_num));
        for (j = 0; j < tree_num; j++) {
            jmpVal = setjmp(jmpbuffer);
            if (jmpVal == 0) {//norm case
                tree[j] = convert_2_KDtree(orgarr, true, rectify);
                rectify = 0;
                previous_j = j;
            }
            else if (jmpVal == 1) {// Null is return by CudaMallocManagement occur, skip, becasue excess Cuda ctrl's memory 
                printf("newNodes is NULL!\n");
                jmpVal = 0;
                //j = store_j;
                continue;
            }
            else if (jmpVal == 2) {//if allocated node memory insufficient
                rectify++;
                jmpVal = 0;
                j = previous_j;//j->j-1
            }
        }
        free(orgarr);
        //printf("traverse------------------------------------------------\n");
        point target;
        point* found;
        target.values[0] = 32751;
        target.values[1] = 33751;
        target.values[2] = 30000;
         cudaMallocManaged(&found, sizeof(point) * (tree_num));//was sizeof(int)
        clock_t traverse_start = clock();
        float time;
        cudaEvent_t start, stop;
        cudaEventCreate(&start);
        cudaEventCreate(&stop);
        cudaEventRecord(start, 0);
        k_nearest_search_k1_GPU << < 1, tree_num >> > (tree, target, tree_num, found);
        cudaDeviceSynchronize();//CPU stop
        cudaEventRecord(stop, 0);
        cudaEventSynchronize(stop);
        cudaEventElapsedTime(&time, start, stop);
        printf("ttraverse all trees time taken%3.6f s\n", time);
        cudaFree(found);//need
        cudaFree(tree);//need
        //free(orgarr);
        //write text to disk here
        printf("\n\n\ntree number %d\tquery points number %llu, true interval %llu \n", tree_num, i, loop_interval);
        write_traverseresult_to_disk(tree_num, i, time, queries_max, queries_min, queries_interval);
        if ((i < 4 * loop_interval) && (loop_interval != 1)) loop_interval /= 2;
    }
    */

 // Final. Traverse metods test; input data from disk. ->tree_num block 1 thread for each block
    /*
    int tree_num;
    int jmpVal;// skip error mem access
    tree_num = 32;
    node** tree;
    unsigned long long i;
    static unsigned long long rectify = 0;
    int j, previous_j, k;
    point* orgarr;
    unsigned long long queries_max = mypow(2, 14);//14
    unsigned long long queries_min = mypow(2, 2);
    unsigned long long loop_interval, queries_interval = mypow(2, 2);
    loop_interval = queries_interval;
    char fname_format[] = "rand_queries_%llu.txt";
    char fname[sizeof fname_format + 128];
    write_Data_head = true;
    for (i = queries_max; i >= queries_min; i /= loop_interval) {//control query points number
        sprintf(fname, fname_format, i);
        orgarr = read_data_from_txt(fname);

        cudaMallocManaged(&tree, sizeof(node) * (tree_num));
        for (j = 0; j < tree_num; j++) {
            jmpVal = setjmp(jmpbuffer);
            if (jmpVal == 0) {//norm case
                tree[j] = convert_2_KDtree(orgarr, true, rectify);
                rectify = 0;
                previous_j = j;
            }
            else if (jmpVal == 1) {// Null is return by CudaMallocManagement occur, skip, becasue excess Cuda ctrl's memory 
                printf("newNodes is NULL!\n");
                jmpVal = 0;
                //j = store_j;
                continue;
            }
            else if (jmpVal == 2) {//if allocated node memory insufficient
                rectify++;
                jmpVal = 0;
                j = previous_j;//j->j-1
            }
        }
        free(orgarr);
        //printf("traverse------------------------------------------------\n");
        point target;
        point* found;
        target.values[0] = 32751;
        target.values[1] = 33751;
        target.values[2] = 30000;
        cudaMallocManaged(&found, sizeof(point) * (tree_num));//was sizeof(int)
        float time;
        cudaEvent_t start, stop;
        int block_num,thread_num_per_block;
        
        for (j = 1; j <= tree_num; j++) {
            block_num = j;
            printf("block_num%d\n", block_num);
            
            thread_num_per_block = tree_num/block_num+(int)(tree_num % block_num!=0);
            cudaEventCreate(&start);
            cudaEventCreate(&stop);
            cudaEventRecord(start, 0);
            k_nearest_search_k1_GPU << < block_num, thread_num_per_block >> > (tree, target, tree_num, found);
            cudaDeviceSynchronize();//CPU stop
            cudaEventRecord(stop, 0);
            cudaEventSynchronize(stop);
            cudaEventElapsedTime(&time, start, stop);
            printf("ttraverse all trees time taken%3.6f s\n", time);
            cudaFree(found);//need
            cudaFree(tree);//need
            //free(orgarr);
            //write text to disk here
            printf("tree number %d\tquery points number %llu, true interval %llu \n\n\n", tree_num, i, loop_interval);
            write_traverseresult_to_disk(tree_num, i, time, queries_max, queries_min, queries_interval,block_num,thread_num_per_block);
            //exit(322);
        }
        if ((i < 4 * loop_interval) && (loop_interval != 1)) loop_interval /= 2;
        else if (loop_interval == 1) break;
    }
    
    */

   // change tree order

    int tree_num;
    int jmpVal;// skip error mem access
    tree_num = 32;
    node** tree;
    node** tree_reversed;
    unsigned long long i;
    static unsigned long long rectify = 0;
    int j, previous_j, k;
    point* orgarr;
    unsigned long long queries_max = mypow(2, 14);//14
    unsigned long long queries_min = mypow(2, 2);
    unsigned long long loop_interval, queries_interval = mypow(2, 2);
    loop_interval = queries_interval;
    char fname_format[] = "rand_queries_%llu.txt";
    char fname[sizeof fname_format + 128];
    write_Data_head = true;
    for (i = queries_max; i >= queries_min; i /= loop_interval) {//control query points number
        sprintf(fname, fname_format, i);
        orgarr = read_data_from_txt(fname);

        cudaMallocManaged(&tree, sizeof(node) * (tree_num));
        cudaMallocManaged(&tree_reversed, sizeof(node) * (tree_num));
        for (j = 0; j < tree_num; j++) {
            jmpVal = setjmp(jmpbuffer);
            if (jmpVal == 0) {//norm case
                tree[j] = convert_2_KDtree(orgarr, true, rectify);
                tree_reversed[tree_num - j] = tree[j];
                rectify = 0;
                previous_j = j;
            }
            else if (jmpVal == 1) {// Null is return by CudaMallocManagement occur, skip, becasue excess Cuda ctrl's memory 
                printf("newNodes is NULL!\n");
                jmpVal = 0;
                //j = store_j;
                continue;
            }
            else if (jmpVal == 2) {//if allocated node memory insufficient
                rectify++;
                jmpVal = 0;
                j = previous_j;//j->j-1
            }
        }
        free(orgarr);
        //printf("traverse------------------------------------------------\n");
        point target;
        point* found;
        target.values[0] = 32751;
        target.values[1] = 33751;
        target.values[2] = 30000;
        cudaMallocManaged(&found, sizeof(point) * (tree_num));//was sizeof(int)
        float time;
        cudaEvent_t start, stop;
        int block_num, thread_num_per_block;

        for (j = 1; j <= tree_num; j++) {
            block_num = j;
            printf("block_num%d\n", block_num);

            thread_num_per_block = tree_num / block_num + (int)(tree_num % block_num != 0);
            cudaEventCreate(&start);
            cudaEventCreate(&stop);
            cudaEventRecord(start, 0);
            k_nearest_search_k1_GPU << < block_num, thread_num_per_block >> > (tree, target, tree_num, found);
            cudaDeviceSynchronize();//CPU stop
            cudaEventRecord(stop, 0);
            cudaEventSynchronize(stop);
            cudaEventElapsedTime(&time, start, stop);
            printf("ttraverse all trees time taken%3.6f s\n", time);
            //cudaFree(found);//need
            //cudaFree(tree);//need
            //free(orgarr);
            //write text to disk here
            printf("tree number %d\tquery points number %llu, true interval %llu \n\n\n", tree_num, i, loop_interval);
            write_traverseresult_to_disk('n',tree_num, i, time, queries_max, queries_min, queries_interval, block_num, thread_num_per_block);
        }
        cudaFree(tree);//need
        ////make reversed
        //node* tmp;
        //for (j = 0; j <= tree_num/2; j++) {
        //    tmp = tree[j];
        //    tree[j] = tree[tree_num - j];
        //    tree[tree_num - j] = tmp;
        //}

        //reverse tree traverse
        for (j = 1; j <= tree_num; j++) {
            block_num = j;
            printf("block_num%d\n", block_num);

            thread_num_per_block = tree_num / block_num + (int)(tree_num % block_num != 0);
            cudaEventCreate(&start);
            cudaEventCreate(&stop);
            cudaEventRecord(start, 0);
            k_nearest_search_k1_GPU << < block_num, thread_num_per_block >> > (tree_reversed, target, tree_num, found);
            cudaDeviceSynchronize();//CPU stop
            cudaEventRecord(stop, 0);
            cudaEventSynchronize(stop);
            cudaEventElapsedTime(&time, start, stop);
            printf("ttraverse all trees time taken%3.6f s\n", time);
            //cudaFree(found);//need
            //cudaFree(tree);//need
            //free(orgarr);
            //write text to disk here
            printf("tree number %d\tquery points number %llu, true interval %llu \n\n\n", tree_num, i, loop_interval);
            write_traverseresult_to_disk('r',tree_num, i, time, queries_max, queries_min, queries_interval, block_num, thread_num_per_block);

        }
        cudaFree(found);//need
        
        cudaFree(tree_reversed);//need
        if ((i < 4 * loop_interval) && (loop_interval != 1)) loop_interval /= 2;
        else if (loop_interval == 1) break;
    }
   
    return clock()-main_start;
}