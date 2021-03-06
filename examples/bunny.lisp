#|
  This file is a part of cl-voxelize project.
  Copyright (c) 2014 Masayuki Takagi (kamonama@gmail.com)
|#

(in-package :cl-user)
(defpackage cl-voxelize-examples
  (:use :cl :cl-voxelize)
  (:export :main))
(in-package :cl-voxelize-examples)


;;;
;;; PLY format to triangles
;;;

(defun triangles (vertices faces)
  (let (ret)
    (dotimes (i (array-dimension faces 0))
      (let ((face (aref faces i)))
        (let ((v0 (aref vertices (nth 0 face)))
              (v1 (aref vertices (nth 1 face)))
              (v2 (aref vertices (nth 2 face))))
          (push (list v0 v1 v2) ret))))
    ret))

(defun ply-to-triangles (path)
  (cl-ply:with-ply-for-reading (plyfile path)
    (let ((vertices (make-array (cl-ply:ply-element-size plyfile "vertex")))
          (faces (make-array (cl-ply:ply-element-size plyfile "face"))))
      ;; read vertices
      (loop repeat (array-dimension vertices 0)
            for i from 0
         do (setf (aref vertices i)
                  (cl-ply:ply-read-element plyfile "vertex")))
      ;; read faces
      (loop repeat (array-dimension faces 0)
            for i from 0
         do (setf (aref faces i)
                  (car (cl-ply:ply-read-element plyfile "face"))))
      ;; get triangles from vertices and faces
      (triangles vertices faces))))


;;;
;;; Output in POV format
;;;

(defun head ()
  "#include \"colors.inc\"
camera {
  location <5.0e-2, 0.2, 0.25>
  look_at  <-3.0e-2, 0.1, 0.0>
  right    <-1.33, 0, 0>
}
light_source {
  <5.0e-2, 0.2, 0.25>
  color White
}
")

(defun sphere (voxel)
  (destructuring-bind (x y z) voxel
    (format nil "sphere {
  <~F,~F,~F>,0.0033
  texture {
    pigment { color White }
  }
}" x y z)))

(defun output (path voxels)
  (with-open-file (out path :direction :output :if-exists :supersede)
    (princ (head) out)
    (dolist (voxel voxels)
      (princ (sphere voxel) out))))


;;;
;;; Main
;;;

(defun main ()
  (let* ((ply-path (asdf:system-relative-pathname :cl-voxelize
                                                  #P"examples/bunny.ply"))
         (pov-path (make-pathname :type "pov" :defaults ply-path)))
    (let ((triangles (ply-to-triangles ply-path))
          (delta 0.006))
      (output pov-path
        (voxelize triangles delta)))))
