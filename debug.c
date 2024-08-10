#include <stdio.h>

#define MAT_IMPLEMENTATION
#include "mat.h"

int main() {
	mat_mesh    *mesh = mat_mesh_load("cube.mat",0);;
	unsigned int mesh_id = 0;

	while (mesh!=NULL && mesh->vert_data!=NULL) {
		if (mesh->name_data!=NULL) {
			printf("\n[NAME]\n%s\n",mesh->name_data);
		}

		if (mesh->vert_data!=NULL) {
			printf("\n[VERTICES]\n");

			for (unsigned int i=0; i<mesh->vert_size; i+=3) {
				printf(
					"%.5f, %.5f, %.5f\n",
					(float)mesh->vert_data[i],
					(float)mesh->vert_data[i+1],
					(float)mesh->vert_data[i+2]
				);
			}
		}

		if (mesh->norm_data!=NULL) {
			printf("\n[NORMALS]\n");

			for (unsigned int i=0; i<mesh->norm_size; i+=3) {
				printf(
					"%.5f, %.5f, %.5f\n",
					(float)mesh->norm_data[i],
					(float)mesh->norm_data[i+1],
					(float)mesh->norm_data[i+2]
				);
			}
		}

		if (mesh->text_data!=NULL) {
			printf("\n[TEXTURES]\n");

			for (unsigned int i=0; i<mesh->text_size; i+=2) {
				printf(
					"%.5f, %.5f\n",
					(float)mesh->text_data[i],
					(float)mesh->text_data[i+1]
				);
			}
		}

		if (mesh->face_data!=NULL) {
			printf("\n[FACES]\n");

			for (unsigned int i=0; i<mesh->face_size; i+=9) {
				for (unsigned int j=0; j<9; j+=3) {
					printf(
						"%u, %u, %u    ",
						(unsigned int)mesh->face_data[i+j],
						(unsigned int)mesh->face_data[i+j+1],
						(unsigned int)mesh->face_data[i+j+2]
					);
				}

				printf("\n");
			}
		}

		mat_mesh_free(mesh);

		mesh = mat_mesh_load("cube.mat",++mesh_id);
	}

	return 0;
}
