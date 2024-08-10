/*
MIT License

Copyright (c) 2024 Dice

Permission is hereby granted, free of charge, to any person obtaining a copy 
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

#ifndef MAT_H
#define MAT_H
#include <stdio.h>

#define MAT_VERSION 2

#define MAT_ATTRIBUTE_META 0x00
#define MAT_ATTRIBUTE_NAME 0x10
#define MAT_ATTRIBUTE_VERT 0x22
#define MAT_ATTRIBUTE_NORM 0x32
#define MAT_ATTRIBUTE_TEXT 0x41
#define MAT_ATTRIBUTE_FACE 0x58
#define MAT_ATTRIBUTE_BIND 0x60
#define MAT_ATTRIBUTE_POSE 0x7F
#define MAT_ATTRIBUTE_TIME 0x80

typedef struct {
	char          *name_data;
	unsigned char *meta_data;
	float         *vert_data;
	float         *norm_data;
	float         *text_data;
	unsigned int  *face_data;
	unsigned int  *bind_data;
	unsigned int   name_size;
	unsigned int   meta_size;
	unsigned int   vert_size;
	unsigned int   norm_size;
	unsigned int   text_size;
	unsigned int   face_size;
	unsigned int   bind_size;
} mat_mesh;

void mat_file_decode(
	FILE         *mat_file,
	unsigned int  attribute,
	unsigned int  id,
	unsigned int *size,
	void        **data
);

mat_mesh* mat_mesh_load(
	char        *filename,
	unsigned int id
);

void mat_mesh_free(
	mat_mesh *mesh
);
#endif

#ifdef MAT_IMPLEMENTATION
#include <malloc.h>

static unsigned int mat_file_decode_uint(
	FILE *mat_file
) {
	return (
		(unsigned int)fgetc(mat_file)<<24|
		(unsigned int)fgetc(mat_file)<<16|
		(unsigned int)fgetc(mat_file)<<8|
		(unsigned int)fgetc(mat_file)
	);
}

static float mat_file_decode_fixed(
	FILE    *mat_file,
	unsigned int integer,
	unsigned int fraction
) {
	if (integer==0 && fraction==0) {
		return (float)fgetc(mat_file);
	}

	unsigned long encoded = 0;
	double        decoded;

	for (unsigned int i=0; i<integer+fraction; i++) {
		encoded=(encoded<<8)|(unsigned long)fgetc(mat_file);
	}

	decoded = (double)encoded;
	decoded = decoded/(1<<(fraction*8));
	decoded = decoded-(1<<(integer*8))/2;

	return (float)decoded;
}

void mat_file_decode(
	FILE         *mat_file,
	unsigned int  attribute,
	unsigned int  id,
	unsigned int *size,
	void        **data
) {
	*data = NULL;
	*size = 0;

	if (mat_file==NULL) {
		return;
	}

	fseek(mat_file,0,SEEK_END);
	unsigned int mat_file_size=ftell(mat_file);
	fseek(mat_file,0,SEEK_SET);

	unsigned int attribute_id=0;

	while (
		!ferror(mat_file) &&
		(unsigned int)ftell(mat_file)<mat_file_size
	) {
		unsigned int attribute_type   = fgetc(mat_file);
		unsigned int attribute_format = fgetc(mat_file);
		unsigned int attribute_count  = mat_file_decode_uint(mat_file);

		if (attribute_type==attribute) {
			if (attribute_id==id) {
				switch(attribute) {
					case MAT_ATTRIBUTE_NAME:
						*data=malloc(attribute_count+1);
						break;
					case MAT_ATTRIBUTE_META:
						*data=malloc(attribute_count);
						break;
					case MAT_ATTRIBUTE_FACE:
						*data=malloc(attribute_count*sizeof(unsigned int));
						break;
					case MAT_ATTRIBUTE_BIND:
						*data=malloc(attribute_count*sizeof(unsigned int));
						break;
					default:
						*data=malloc(attribute_count*sizeof(float));
				}

				if (*data==NULL) {
					return;
				}

				*size=attribute_count;

				for (unsigned int i=0; i<attribute_count; i++) {
					float value=mat_file_decode_fixed(
						mat_file,
						attribute_format>>4,
						attribute_format&0x0F
					);

					switch(attribute) {
						case MAT_ATTRIBUTE_NAME:
							((char*)(*data))[i]=(char)value;
							break;
						case MAT_ATTRIBUTE_META:
							((unsigned char*)(*data))[i]=(unsigned char)value;
							break;
						case MAT_ATTRIBUTE_FACE:
							((unsigned int*)(*data))[i]=(unsigned int)value;
							break;
						case MAT_ATTRIBUTE_BIND:
							((unsigned int*)(*data))[i]=(unsigned int)value;
							break;
						default:
							((float*)(*data))[i]=value;
					}
				}

				if (attribute==MAT_ATTRIBUTE_NAME) {
					((char*)(*data))[attribute_count]='\0';
				}

				return;
			}

			attribute_id++;
		}

		if (attribute_format==0) {
			fseek(
				mat_file,
				ftell(mat_file)+
				attribute_count,
				SEEK_SET
			);
		} else {
			fseek(
				mat_file,
				ftell(mat_file)+
				attribute_count*
				((attribute_format>>4)+(attribute_format&0x0F)),
				SEEK_SET
			);
		}
	}

	return;
}

mat_mesh* mat_mesh_load(
	char        *filename,
	unsigned int id
) {
	FILE *mat_file=fopen(
		filename,
		"rb"
	);

	if (mat_file==NULL) {
		return NULL;
	}

	mat_mesh *mesh=malloc(sizeof(mat_mesh));

	if (mesh==NULL) {
		fclose(mat_file);

		return NULL;
	}

	mat_file_decode(
		mat_file,
		MAT_ATTRIBUTE_VERT,
		id,
		&mesh->vert_size,
		(void**)&mesh->vert_data
	);
	mat_file_decode(
		mat_file,
		MAT_ATTRIBUTE_NAME,
		id,
		&mesh->name_size,
		(void**)&mesh->name_data
	);
	mat_file_decode(
		mat_file,
		MAT_ATTRIBUTE_META,
		id,
		&mesh->meta_size,
		(void**)&mesh->meta_data
	);
	mat_file_decode(
		mat_file,
		MAT_ATTRIBUTE_NORM,
		id,
		&mesh->norm_size,
		(void**)&mesh->norm_data
	);
	mat_file_decode(
		mat_file,
		MAT_ATTRIBUTE_TEXT,
		id,
		&mesh->text_size,
		(void**)&mesh->text_data
	);
	mat_file_decode(
		mat_file,
		MAT_ATTRIBUTE_FACE,
		id,
		&mesh->face_size,
		(void**)&mesh->face_data
	);
	mat_file_decode(
		mat_file,
		MAT_ATTRIBUTE_BIND,
		id,
		&mesh->bind_size,
		(void**)&mesh->bind_data
	);

	fclose(mat_file);

	return mesh;
}

void mat_mesh_free(
	mat_mesh *mesh
) {
	if (mesh==NULL) {
		return;
	}

	if (mesh->name_data!=NULL) free(mesh->name_data);
	if (mesh->meta_data!=NULL) free(mesh->meta_data);
	if (mesh->vert_data!=NULL) free(mesh->vert_data);
	if (mesh->norm_data!=NULL) free(mesh->norm_data);
	if (mesh->text_data!=NULL) free(mesh->text_data);
	if (mesh->face_data!=NULL) free(mesh->face_data);
	if (mesh->bind_data!=NULL) free(mesh->bind_data);

	free(mesh);
}
#endif
